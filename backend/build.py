# build_once.py
import json
import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer
import os

MODEL_DIR = os.path.join("models", "multilingual-e5-small")
QA_DATA_FILE = "qa_data.json"
EMBEDDINGS_FILE = os.path.join("models", "embeddings.npy")
ANSWERS_FILE = os.path.join("models", "answers.json")
QUESTIONS_FILE = os.path.join("models", "questions.json")

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

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

print("بارگذاری مدل...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
model = AutoModel.from_pretrained(MODEL_DIR).to(device)
model.eval()

with open(QA_DATA_FILE, "r", encoding="utf-8") as f:
    data = json.load(f)

passages = ["passage: " + item["question"] for item in data]
answers = [item["answer"] for item in data]
raw_questions = [item["question"] for item in data]

print("محاسبه embedding ها (ممکن است چند دقیقه طول بکشد)...")
embeddings = encode_texts(passages, tokenizer, model, batch_size=8)

os.makedirs("models", exist_ok=True)
np.save(EMBEDDINGS_FILE, embeddings)
with open(ANSWERS_FILE, "w", encoding="utf-8") as f:
    json.dump(answers, f, ensure_ascii=False)
with open(QUESTIONS_FILE, "w", encoding="utf-8") as f:
    json.dump(raw_questions, f, ensure_ascii=False)

print("✅ فایل‌های embeddings.npy, answers.json, questions.json ساخته شدند.")