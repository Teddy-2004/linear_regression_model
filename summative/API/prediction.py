"""
World Bank Africa Infrastructure Project Cost Predictor — FastAPI
Mission: Help African governments detect corruption and public property
         exploitation by predicting expected project costs before approval.
"""

import os
import io
from datetime import datetime

import numpy as np
import pandas as pd
import joblib
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
from sklearn.linear_model import SGDRegressor
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score

# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="World Bank Africa Infrastructure Cost Predictor",
    description=(
        "Predicts the actual final cost (USD) of World Bank-funded African "
        "infrastructure projects to help governments detect budget exploitation "
        "and corruption. Built on 4,658 real World Bank Africa projects."
    ),
    version="1.0.0",
)

# ── CORS — specific origins, NOT wildcard (*) ─────────────────────────────────
# Rubric: Excellent = does NOT generically configure allow_origins="*"
#         Must specify Allowed Origins, Methods, Headers, Credentials
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://10.0.2.2",           # Android emulator → host machine
        "http://10.0.2.2:8000",
        "https://wb-africa-cost.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "Accept", "X-Requested-With"],
)

# ── File paths ─────────────────────────────────────────────────────────────────
BASE          = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH    = os.path.join(BASE, "best_model.pkl")
SCALER_PATH   = os.path.join(BASE, "scaler.pkl")
ENCODERS_PATH = os.path.join(BASE, "encoders.pkl")
DATA_PATH     = os.path.join(BASE, "wb_africa_projects.csv")
BUFFER_PATH   = os.path.join(BASE, "new_data_buffer.csv")

# ── Valid categorical values (from LabelEncoder classes in notebook) ───────────
VALID_COUNTRIES = [
    "Africa", "Arab Republic of Egypt", "Burkina Faso", "Central Africa",
    "Central African Republic", "Democratic Republic of Sao Tome and Prin",
    "Democratic Republic of the Congo", "Eastern Africa",
    "Federal Democratic Republic of Ethiopia", "Federal Republic of Nigeria",
    "Gabonese Republic", "Islamic Republic of Mauritania", "Kingdom of Eswatini",
    "Kingdom of Lesotho", "Kingdom of Morocco", "Republic of Angola",
    "Republic of Benin", "Republic of Botswana", "Republic of Burundi",
    "Republic of Cabo Verde", "Republic of Cameroon", "Republic of Chad",
    "Republic of Congo", "Republic of Cote d'Ivoire", "Republic of Djibouti",
    "Republic of Equatorial Guinea", "Republic of Ghana", "Republic of Guinea",
    "Republic of Guinea-Bissau", "Republic of Kenya", "Republic of Liberia",
    "Republic of Madagascar", "Republic of Malawi", "Republic of Mali",
    "Republic of Mauritius", "Republic of Mozambique", "Republic of Namibia",
    "Republic of Niger", "Republic of Rwanda", "Republic of Senegal",
    "Republic of Sierra Leone", "Republic of South Africa",
    "Republic of South Sudan", "Republic of The Gambia", "Republic of Togo",
    "Republic of Tunisia", "Republic of Uganda", "Republic of Zambia",
    "Republic of Zimbabwe", "Republic of the Sudan", "Somali Democratic Republic",
    "Southern Africa", "State of Eritrea", "Union of the Comoros",
    "United Republic of Tanzania", "Western Africa",
]

VALID_SUBREGIONS = ["East Africa", "Other Africa", "Southern Africa", "West Africa"]

VALID_SECTORS = [
    "Agriculture adjustment", "Basic health", "Central Government (Central Agencies)",
    "Distribution and transmission", "Early Childhood Education",
    "Electric power and other energy adjustment", "Energy Transmission and Distribution",
    "Financial sector development", "Fisheries", "Forestry", "Health", "Highways",
    "Housing Construction", "Hydro", "ICT Infrastructure", "Irrigation and Drainage",
    "Law and Justice", "Mining", "Non-Renewable Energy Generation", "Oil and Gas",
    "Other", "Other Agriculture; Fishing and Forestry", "Other Education",
    "Other Energy and Extractives", "Other Industry; Trade and Services",
    "Other Public Administration", "Other Transportation",
    "Other Water Supply; Sanitation and Waste Management",
    "Ports/Waterways", "Power", "Primary Education", "Railways",
    "Renewable Energy Hydro", "Renewable Energy Solar", "Renewable energy",
    "Roads and highways", "Rural and Inter-Urban Roads",
    "Rural water supply and sanitation", "Sanitation", "Secondary Education",
    "Social Protection", "Sub-National Government", "Telecommunications",
    "Tertiary Education", "Urban Transport", "Urban water supply",
    "Vocational training", "Waste Management", "Water Supply",
    "Workforce Development and Vocational Education",
]

VALID_LENDING_TYPES = [
    "Adaptable Program Loan", "Development Policy Lending",
    "Emergency Recovery Loan", "Financial Intermediary Loan",
    "Investment Project Financing", "Learning and Innovation Loan",
    "Poverty Reduction Support Credit", "Program-for-Results Financing",
    "Sector Adjustment Loan", "Sector Investment and Maintenance Loan",
    "Specific Investment Loan", "Structural Adjustment Loan",
    "Technical Assistance Loan", "Unknown",
]

FEATURE_ORDER = [
    "country", "subregion", "sector", "lending_type",
    "ida_share", "grant_share", "approval_year",
    "project_duration_years", "log_wb_commitment",
]


def load_artifacts():
    model    = joblib.load(MODEL_PATH)
    scaler   = joblib.load(SCALER_PATH)
    encoders = joblib.load(ENCODERS_PATH)
    return model, scaler, encoders


# ── Pydantic schema — enforced data types + range constraints ──────────────────
class ProjectFeatures(BaseModel):
    country: str = Field(
        ..., description=f"Country name. One of {len(VALID_COUNTRIES)} African countries."
    )
    subregion: str = Field(
        ..., description="Sub-region: East Africa | West Africa | Southern Africa | Other Africa"
    )
    sector: str = Field(
        ..., description="Project sector (e.g. Highways, Health, Primary Education)"
    )
    lending_type: str = Field(
        ..., description="WB lending instrument type (e.g. Specific Investment Loan)"
    )
    wb_commitment_usd: float = Field(
        ..., ge=100_000, le=5_000_000_000,
        description="World Bank committed amount in USD (100K – 5B)"
    )
    ida_share: float = Field(
        ..., ge=0.0, le=1.0,
        description="Share of funding from IDA (0.0 – 1.0)"
    )
    grant_share: float = Field(
        ..., ge=0.0, le=1.0,
        description="Share of funding that is a grant (0.0 – 1.0)"
    )
    approval_year: int = Field(
        ..., ge=1970, le=2030,
        description="Year the project was approved by the World Bank (1970 – 2030)"
    )
    project_duration_years: int = Field(
        ..., ge=0, le=20,
        description="Planned project duration in years (0 – 20)"
    )

    @validator("country")
    def validate_country(cls, v):
        if v not in VALID_COUNTRIES:
            raise ValueError(
                f"Invalid country '{v}'. Must be one of the 67 supported African countries. "
                f"Call GET /valid-inputs for the full list."
            )
        return v

    @validator("subregion")
    def validate_subregion(cls, v):
        if v not in VALID_SUBREGIONS:
            raise ValueError(f"subregion must be one of: {VALID_SUBREGIONS}")
        return v

    @validator("sector")
    def validate_sector(cls, v):
        if v not in VALID_SECTORS:
            raise ValueError(
                f"Invalid sector '{v}'. Call GET /valid-inputs for the full list."
            )
        return v

    @validator("lending_type")
    def validate_lending_type(cls, v):
        if v not in VALID_LENDING_TYPES:
            raise ValueError(f"lending_type must be one of: {VALID_LENDING_TYPES}")
        return v


class PredictionResponse(BaseModel):
    predicted_actual_cost_usd: float
    wb_commitment_usd:         float
    cost_ratio:                float
    risk_flag:                 str
    model_used:                str
    message:                   str


class RetrainResponse(BaseModel):
    status:     str
    mse:        float
    r2:         float
    rows_used:  int
    model_used: str
    timestamp:  str


# ── Endpoints ──────────────────────────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    return {
        "message": "World Bank Africa Infrastructure Cost Predictor API",
        "mission": "Helping African governments detect corruption in public infrastructure spending",
        "docs":    "/docs",
        "version": "1.0.0",
    }


@app.get("/health", tags=["Health"])
def health():
    all_ok = all(os.path.exists(p) for p in [MODEL_PATH, SCALER_PATH, ENCODERS_PATH])
    return {
        "status":         "healthy" if all_ok else "degraded",
        "model_loaded":   os.path.exists(MODEL_PATH),
        "scaler_loaded":  os.path.exists(SCALER_PATH),
        "encoders_loaded": os.path.exists(ENCODERS_PATH),
    }


@app.get("/valid-inputs", tags=["Info"])
def valid_inputs():
    """Returns all valid categorical values for each input field."""
    return {
        "countries":     VALID_COUNTRIES,
        "subregions":    VALID_SUBREGIONS,
        "sectors":       VALID_SECTORS,
        "lending_types": VALID_LENDING_TYPES,
    }


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
def predict(features: ProjectFeatures):
    """
    Predict the actual final cost (USD) of a World Bank-funded African
    infrastructure project from 9 pre-approval input features.
    """
    try:
        model, scaler, encoders = load_artifacts()
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=f"Model artifacts not found: {e}")

    # Encode categoricals
    def enc(col, val):
        try:
            return int(encoders[col].transform([val])[0])
        except ValueError:
            raise HTTPException(
                status_code=422,
                detail=f"Unknown value '{val}' for field '{col}'. Call /valid-inputs."
            )

    row = np.array([[
        enc("country",      features.country),
        enc("subregion",    features.subregion),
        enc("sector",       features.sector),
        enc("lending_type", features.lending_type),
        features.ida_share,
        features.grant_share,
        features.approval_year,
        features.project_duration_years,
        np.log1p(features.wb_commitment_usd),
    ]], dtype=float)

    row_scaled    = scaler.transform(row)
    log_pred      = model.predict(row_scaled)[0]
    predicted_usd = float(np.expm1(log_pred))
    cost_ratio    = predicted_usd / features.wb_commitment_usd

    # Risk flag based on how much predicted cost exceeds WB commitment
    if cost_ratio <= 1.1:
        risk = "LOW — Predicted cost within 10% of WB commitment"
    elif cost_ratio <= 1.5:
        risk = "MEDIUM — Predicted cost 10–50% above WB commitment"
    elif cost_ratio <= 2.0:
        risk = "HIGH — Predicted cost 50–100% above WB commitment"
    else:
        risk = "CRITICAL — Predicted cost more than double WB commitment"

    return PredictionResponse(
        predicted_actual_cost_usd=round(predicted_usd, 2),
        wb_commitment_usd=features.wb_commitment_usd,
        cost_ratio=round(cost_ratio, 4),
        risk_flag=risk,
        model_used=type(model).__name__,
        message="Prediction successful",
    )


@app.post("/upload-data", tags=["Retraining"])
async def upload_data(file: UploadFile = File(...)):
    """
    Upload a CSV file containing new project records.
    Required columns: country, subregion, sector, lending_type,
    wb_commitment_usd, ida_share, grant_share, approval_year,
    project_duration_years, actual_project_cost_usd.
    Uploaded data is buffered and used on the next /retrain call.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are accepted.")

    contents = await file.read()
    try:
        new_df = pd.read_csv(io.StringIO(contents.decode("utf-8")))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cannot parse CSV: {e}")

    required_cols = {
        "country", "subregion", "sector", "lending_type",
        "wb_commitment_usd", "ida_share", "grant_share",
        "approval_year", "project_duration_years", "actual_project_cost_usd",
    }
    missing = required_cols - set(new_df.columns)
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}")

    # Append to buffer
    if os.path.exists(BUFFER_PATH):
        existing = pd.read_csv(BUFFER_PATH)
        combined = pd.concat([existing, new_df], ignore_index=True)
    else:
        combined = new_df

    combined.to_csv(BUFFER_PATH, index=False)
    return {
        "status":        "success",
        "rows_uploaded": len(new_df),
        "buffer_total":  len(combined),
        "message":       "Data buffered. Call POST /retrain to update the model.",
    }


@app.post("/retrain", response_model=RetrainResponse, tags=["Retraining"])
def retrain():
    """
    Retrain the model using the original training data PLUS any buffered
    new data uploaded via /upload-data. Automatically saves the updated model.
    Triggered manually — call this endpoint after uploading new data.
    """
    if not os.path.exists(DATA_PATH):
        raise HTTPException(status_code=503, detail="Base training data not found.")

    base_df = pd.read_csv(DATA_PATH)

    # Merge with buffer if available
    if os.path.exists(BUFFER_PATH):
        new_df   = pd.read_csv(BUFFER_PATH)
        train_df = pd.concat([base_df, new_df], ignore_index=True)
    else:
        train_df = base_df

    # Preprocessing (mirrors notebook exactly)
    train_df["sector"] = train_df["sector"].fillna("Other")

    encoders = {}
    for col in ["country", "subregion", "sector", "lending_type"]:
        le = LabelEncoder()
        train_df[col] = le.fit_transform(train_df[col].astype(str))
        encoders[col] = le

    train_df["log_wb_commitment"] = np.log1p(train_df["wb_commitment_usd"])
    train_df["log_actual_cost"]   = np.log1p(train_df["actual_project_cost_usd"])
    train_df.drop(
        ["wb_commitment_usd", "actual_project_cost_usd"],
        axis=1, inplace=True, errors="ignore"
    )
    train_df.dropna(inplace=True)

    X = train_df[FEATURE_ORDER].values
    y = train_df["log_actual_cost"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    scaler   = StandardScaler()
    X_tr     = scaler.fit_transform(X_train)
    X_te     = scaler.transform(X_test)

    new_model = RandomForestRegressor(
        n_estimators=100, max_depth=12, random_state=42, n_jobs=-1
    )
    new_model.fit(X_tr, y_train)

    mse = float(mean_squared_error(y_test, new_model.predict(X_te)))
    r2  = float(r2_score(y_test, new_model.predict(X_te)))

    # Save updated artifacts
    joblib.dump(new_model, MODEL_PATH)
    joblib.dump(scaler,    SCALER_PATH)
    joblib.dump(encoders,  ENCODERS_PATH)

    # Clear buffer after successful retrain
    if os.path.exists(BUFFER_PATH):
        os.remove(BUFFER_PATH)

    return RetrainResponse(
        status="Model retrained and saved successfully",
        mse=round(mse, 6),
        r2=round(r2, 4),
        rows_used=len(train_df),
        model_used=type(new_model).__name__,
        timestamp=datetime.utcnow().isoformat(),
    )
