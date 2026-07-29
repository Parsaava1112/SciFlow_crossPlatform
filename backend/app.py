import os
import json
import numpy as np
import torch
from fastapi import FastAPI
from pydantic import BaseModel
from transformers import AutoModel, AutoTokenizer
from sklearn.neighbors import NearestNeighbors

app = FastAPI()

# ===================== مسیرها =====================
MODEL_DIR = os.path.join("models", "multilingual-e5-small")
QA_DATA_FILE = "qa_data.json"

EMBEDDINGS_FILE = os.path.join("models", "embeddings.npy")
ANSWERS_FILE = os.path.join("models", "answers.json")
QUESTIONS_FILE = os.path.join("models", "questions.json")

# ===================== متغیرهای سراسری =====================
model = None
tokenizer = None
answers = []
questions = []
nn_model = None
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

THRESHOLD = 0.7

# ===================== توابع کمکی =====================
def mean_pooling(model_output, attention_mask):
    """
    میانگین‌گیری از token embeddings با در نظر گرفتن attention mask
    """
    token_embeddings = model_output[0]  # First element of model_output contains all token embeddings
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

def encode_texts(texts, batch_size=32):
    """
    دریافت لیست متون، تولید embedding های نرمالایز شده
    """
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

def build_index_if_missing():
    global model, tokenizer
    if os.path.exists(EMBEDDINGS_FILE):
        print("✅ فایل embeddings.npy وجود دارد. نیاز به بازسازی نیست.")
        return

    print("⚠️ فایل embeddings یافت نشد. در حال ساخت از qa_data.json ...")
    if model is None or tokenizer is None:
        print("بارگذاری مدل و توکنایزر از مسیر محلی ...")
        if not os.path.exists(MODEL_DIR):
            raise FileNotFoundError(f"پوشه مدل {MODEL_DIR} وجود ندارد.")
        tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
        model = AutoModel.from_pretrained(MODEL_DIR).to(device)
        model.eval()

    if not os.path.exists(QA_DATA_FILE):
        raise FileNotFoundError(f"فایل {QA_DATA_FILE} را در کنار app.py قرار دهید.")

    with open(QA_DATA_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    passages = ["passage: " + item["question"] for item in data]
    ans = [item["answer"] for item in data]
    raw_qs = [item["question"] for item in data]

    print("محاسبه embedding ها...")
    embeddings = encode_texts(passages)

    os.makedirs("models", exist_ok=True)
    np.save(EMBEDDINGS_FILE, embeddings)
    with open(ANSWERS_FILE, "w", encoding="utf-8") as f:
        json.dump(ans, f, ensure_ascii=False)
    with open(QUESTIONS_FILE, "w", encoding="utf-8") as f:
        json.dump(raw_qs, f, ensure_ascii=False)

    print("✅ فایل‌های embeddings، answers و questions ساخته شدند.")

def load_data_and_model():
    global model, tokenizer, answers, questions, nn_model

    if model is None or tokenizer is None:
        print("بارگذاری مدل و توکنایزر...")
        if not os.path.exists(MODEL_DIR):
            raise FileNotFoundError(f"پوشه مدل {MODEL_DIR} وجود ندارد.")
        tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
        model = AutoModel.from_pretrained(MODEL_DIR).to(device)
        model.eval()

    embeddings = np.load(EMBEDDINGS_FILE)
    nn_model = NearestNeighbors(n_neighbors=min(3, len(embeddings)), metric="cosine")
    nn_model.fit(embeddings)

    with open(ANSWERS_FILE, "r", encoding="utf-8") as f:
        answers = json.load(f)
    with open(QUESTIONS_FILE, "r", encoding="utf-8") as f:
        questions = json.load(f)

    print("✅ مدل و داده‌ها بارگذاری شدند. سرور آماده است.")

# ===================== رویداد startup =====================
@app.on_event("startup")
async def startup():
    build_index_if_missing()
    load_data_and_model()

# ===================== مدل‌های درخواست و پاسخ =====================
class AskRequest(BaseModel):
    question: str

class AskResponse(BaseModel):
    answer: str
    is_from_db: bool
    suggestions: list[str] = []

# ===================== API اصلی =====================
@app.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest):
    user_q = request.question.strip()
    if not user_q:
        return AskResponse(answer="لطفاً یک سوال بپرسید.", is_from_db=False)

    # embedding سوال کاربر
    query_emb = encode_texts(["query: " + user_q])

    distances, indices = nn_model.kneighbors(query_emb, n_neighbors=min(3, len(answers)))
    best_sim = 1.0 - distances[0][0]
    best_idx = indices[0][0]

    if best_sim >= THRESHOLD:
        return AskResponse(answer=answers[best_idx], is_from_db=True)
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)