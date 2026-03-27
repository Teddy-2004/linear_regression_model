# 🌍 World Bank Africa Infrastructure Project Cost Predictor

## Mission & Problem
This project develops a machine learning solution to help African governments detect potential budget exploitation in World Bank-funded public infrastructure projects. By predicting the actual final project cost from pre-approval features, oversight bodies can flag projects where costs are likely to significantly exceed the World Bank's initial commitment — a key indicator of procurement fraud and fund misuse.

**Dataset:** World Bank Projects & Operations — 4,658 African infrastructure projects (1970s–2019). Source: https://www.kaggle.com/datasets/theworldbank/world-bank-projects-operations

## 🔗 Public API Endpoint (Swagger UI)
https://wb-africa-cost.onrender.com/docs

## 🎥 Video Demo
https://youtu.be/G5al_uGGkik 

## 🤖 Model Results
| Model | MSE | RMSE | R² |
|---|---|---|---|
| Linear Regression | 0.1265 | 0.3556 | 0.9229 |
| Decision Tree | 0.1400 | 0.3742 | 0.9147 |
| **Random Forest** | **0.1181** | **0.3436** | **0.9281** |

## 🚀 Run API Locally
```bash
cd summative/API && pip install -r requirements.txt
uvicorn prediction:app --reload --host 0.0.0.0 --port 8000
```
Swagger UI: http://localhost:8000/docs

## 📱 Run Flutter App
```bash
cd summative/FlutterApp && flutter pub get && flutter run
```
Update `_apiBase` in `lib/main.dart` to your Render URL or `http://10.0.2.2:8000` for emulator.

## 🌐 Deploy to Render
Push summative/API/ to GitHub → Web Service on render.com → Build: `pip install -r requirements.txt` → Start: `uvicorn prediction:app --host 0.0.0.0 --port $PORT`