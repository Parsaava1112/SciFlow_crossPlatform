import os
import json
import hashlib
import numpy as np
import torch
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, Field, validator
from transformers import AutoModel, AutoTokenizer, AutoModelForSeq2SeqLM, pipeline
from sklearn.neighbors import NearestNeighbors
from typing import Optional

app = FastAPI()

# ===================== تنظیمات امنیتی =====================
ADMIN_SECRET = "CHANGE_ME_TO_A_STRONG_RANDOM_STRING"  # برای تأیید سوالات

# ===================== مسیرها =====================
MODEL_DIR = os.path.join("models", "multilingual-e5-small")
PARAPHRASER_DIR = os.path.join("models", "persian-t5-paraphraser")  # اختیاری

QA_DATA_FILE = "qa_data.json"
PENDING_QA_FILE = "pending_qa.json"

EMBEDDINGS_FILE = os.path.join("models", "embeddings.npy")
ANSWERS_FILE = os.path.join("models", "answers.json")
QUESTIONS_FILE = os.path.join("models", "questions.json")

# ===================== متغیرهای سراسری =====================
embedding_tokenizer = None
embedding_model = None
paraphraser = None      # اگر مدل پارافریز بارگذاری شود
answers = []
questions = []
nn_model = None
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

THRESHOLD = 0.7

# ===================== توابع Embedding =====================
def mean_pooling(model_output, attention_mask):
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

def encode_texts(texts, tokenizer, model, batch_size=8):
    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        encoded_input = tokenizer(batch, padding=True, truncation=True, return_tensors='pt').to(device)
        with torch.no_grad():
            model_output = model(**encoded_input)
        embeddings = mean_pooling(model_output, encoded_input['attention_mask'])
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        all_embeddings.append(embeddings.cpu().numpy())
    return np.concatenate(all_embeddings, axis=0)

# ===================== مدیریت فایل‌ها =====================
def load_qa_data(filepath):
    if not os.path.exists(filepath):
        return []
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)

def save_qa_data(filepath, data):
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def rebuild_index_from_main():
    global nn_model, answers, questions
    data = load_qa_data(QA_DATA_FILE)
    passages = ["passage: " + item["question"] for item in data]
    answers = [item["answer"] for item in data]
    questions = [item["question"] for item in data]

    if not data:
        # اگر دیتایی نبود، یک ایندکس خالی نسازیم
        nn_model = None
        return

    print(f"بازسازی ایندکس با {len(data)} رکورد...")
    embs = encode_texts(passages, embedding_tokenizer, embedding_model, batch_size=8)
    np.save(EMBEDDINGS_FILE, embs)
    with open(ANSWERS_FILE, "w", encoding="utf-8") as f:
        json.dump(answers, f, ensure_ascii=False)
    with open(QUESTIONS_FILE, "w", encoding="utf-8") as f:
        json.dump(questions, f, ensure_ascii=False)

    nn_model = NearestNeighbors(n_neighbors=min(3, len(embs)), metric="cosine")
    nn_model.fit(embs)

def load_paraphraser():
    global paraphraser
    if os.path.exists(PARAPHRASER_DIR):
        try:
            print("بارگذاری مدل پارافریز فارسی (سبک)...")
            paraphraser = pipeline(
                "text2text-generation",
                model=PARAPHRASER_DIR,
                tokenizer=PARAPHRASER_DIR,
                device=-1  # CPU
            )
        except Exception as e:
            print(f"خطا در بارگذاری مدل پارافریز: {e}")
            paraphraser = None

# ===================== رویداد startup =====================
@app.on_event("startup")
async def startup():
    global embedding_model, embedding_tokenizer, nn_model, answers, questions

    # ۱. بارگذاری مدل embedding
    print("بارگذاری مدل embedding...")
    embedding_tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
    embedding_model = AutoModel.from_pretrained(MODEL_DIR).to(device)
    embedding_model.eval()

    # ۲. اگر فایل embeddings از قبل موجود بود، فقط بارگذاری کن
    if os.path.exists(EMBEDDINGS_FILE):
        print("بارگذاری ایندکس از پیش‌ساخته شده...")
        embs = np.load(EMBEDDINGS_FILE)
        with open(ANSWERS_FILE, "r", encoding="utf-8") as f:
            answers = json.load(f)
        with open(QUESTIONS_FILE, "r", encoding="utf-8") as f:
            questions = json.load(f)
        nn_model = NearestNeighbors(n_neighbors=min(3, len(embs)), metric="cosine")
        nn_model.fit(embs)
    else:
        print("⚠️  فایل embeddings وجود ندارد. لطفاً ابتدا با build_once.py ایندکس را بسازید.")
        # در صورت نبود، سرور همچنان بالا می‌آید اما جستجو کار نمی‌کند.

    # ۳. بارگذاری مدل پارافریز (اگر موجود باشد)
    load_paraphraser()

    print("🚀 سرور آماده است.")

# ===================== Health Check =====================
@app.get("/")
async def root():
    return {
        "status": "ok",
        "message": "SciFlow backend is running",
        "qa_count": len(answers),
        "pending_count": len(load_qa_data(PENDING_QA_FILE))
    }

# ===================== مدل‌های Pydantic =====================
class AskRequest(BaseModel):
    question: str

class AskResponse(BaseModel):
    answer: str
    is_from_db: bool
    suggestions: list[str] = []

class LearnRequest(BaseModel):
    question: str = Field(..., min_length=3, max_length=500)
    answer: str = Field(..., min_length=5, max_length=2000)

    @validator('question')
    def validate_question(cls, v):
        if any(link in v for link in ['http', 'www.', '.com', '.ir']):
            raise ValueError('سوال نمی‌تواند حاوی لینک باشد.')
        return v.strip()

    @validator('answer')
    def validate_answer(cls, v):
        if any(link in v for link in ['http', 'www.', '.com', '.ir']):
            raise ValueError('پاسخ نمی‌تواند حاوی لینک باشد.')
        return v.strip()

class ApproveRequest(BaseModel):
    ids: Optional[list[int]] = None   # اگر خالی بماند، همه تأیید می‌شوند

# ===================== API اصلی =====================
@app.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest):
    user_q = request.question.strip()
    if not user_q or nn_model is None:
        return AskResponse(answer="سیستم آماده نیست.", is_from_db=False)

    query_emb = encode_texts(["query: " + user_q], embedding_tokenizer, embedding_model, batch_size=1)

    k = min(3, len(answers))
    distances, indices = nn_model.kneighbors(query_emb, n_neighbors=k)
    best_sim = 1.0 - distances[0][0]
    best_idx = indices[0][0]

    if best_sim >= THRESHOLD:
        raw_answer = answers[best_idx]
        # در صورت وجود مدل پارافریز، پاسخ را بازنویسی کن
        if paraphraser:
            try:
                prompt = f"سوال: {user_q}\nپاسخ: {raw_answer}\nبازنویسی روان:"
                result = paraphraser(prompt, max_length=128, num_return_sequences=1)
                final_answer = result[0]['generated_text'].strip()
            except:
                final_answer = raw_answer
        else:
            final_answer = raw_answer
        return AskResponse(answer=final_answer, is_from_db=True)
    else:
        suggestions = []
        for i, dist in enumerate(distances[0]):
            sim = 1.0 - dist
            if sim > 0.4:
                suggestions.append(questions[indices[0][i]])
        fallback_msg = "متأسفم، پاسخی برای این سوال در پایگاه داده یافت نشد. 🤔"
        if suggestions:
            fallback_msg += "\n\nشاید منظور شما یکی از این سوال‌ها باشد:"
        return AskResponse(answer=fallback_msg, is_from_db=False, suggestions=suggestions)

# ===================== یادگیری پویا =====================
@app.post("/learn")
async def learn(request: LearnRequest):
    # بررسی تکراری نبودن در دیتابیس اصلی
    if any(item['question'] == request.question for item in load_qa_data(QA_DATA_FILE)):
        raise HTTPException(status_code=400, detail="این سوال از قبل در پایگاه داده وجود دارد.")

    pending = load_qa_data(PENDING_QA_FILE)
    # بررسی تکراری در pending
    if any(item['question'] == request.question for item in pending):
        raise HTTPException(status_code=400, detail="این سوال قبلاً پیشنهاد شده و در انتظار تأیید است.")

    # افزودن به pending
    new_entry = {
        "id": len(pending) + 1,
        "question": request.question,
        "answer": request.answer,
        "hash": hashlib.md5(request.question.encode()).hexdigest()[:8]
    }
    pending.append(new_entry)
    save_qa_data(PENDING_QA_FILE, pending)

    return {"status": "pending", "message": "سوال شما ثبت شد و پس از بررسی تأیید خواهد شد."}

# ===================== تأیید توسط مدیر =====================
@app.post("/admin/approve")
async def approve(request: ApproveRequest, x_admin_secret: str = Header(None)):
    if x_admin_secret != ADMIN_SECRET:
        raise HTTPException(status_code=403, detail="دسترسی غیرمجاز")

    pending = load_qa_data(PENDING_QA_FILE)
    if not pending:
        return {"message": "هیچ سوالی برای تأیید وجود ندارد."}

    if request.ids:
        # تأیید موارد مشخص
        ids_set = set(request.ids)
        approved = [item for item in pending if item['id'] in ids_set]
        remaining = [item for item in pending if item['id'] not in ids_set]
    else:
        approved = pending
        remaining = []

    if approved:
        main_data = load_qa_data(QA_DATA_FILE)
        main_data.extend(approved)
        save_qa_data(QA_DATA_FILE, main_data)
        # بازسازی ایندکس
        rebuild_index_from_main()

    save_qa_data(PENDING_QA_FILE, remaining)
    return {
        "approved_count": len(approved),
        "remaining_count": len(remaining)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)