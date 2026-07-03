from pymongo import MongoClient
from fastapi import FastAPI
from bson import ObjectId

client = MongoClient("mongodb://116.203.251.38:27017")      # Verbindung zur MongoDB
db = client["testdb"]       
collection = db["test"]     
app = FastAPI()                      

@app.get("/health")                                         # Root-Endpoint
def root():
    return {"message": "API läuft"}

name = "Indi"

dictionary = {
    "name": "Indi",
    "alter": 12,
    "hobbies": ["goonen", "golfen", "coden"]
}

@app.post("/add_user")                                       # Benutzer hinzufügen
def add_user(user_dict: dict):
    
    if db["users"].find_one({"username": user_dict["username"]}):
        return {"error": "User already exists"}
    
    result = db["users"].insert_one(user_dict)
    return {"id": str(result.inserted_id), "username": user_dict["username"]}

@app.get("/get_user")                                       # Benutzer abrufen
def get_user(username: str):
    user = db["users"].find_one({"username": username})
    if user:
        user["_id"] = str(user["_id"])
        return user
    return {"error": "User not found"}

@app.post("/add_card")                                       # Karte hinzufügen
def add_card(card_dict: dict):

    if db["cards"].find_one({"_id": card_dict["_id"]}):
        return {"error": "Card of thet id already exists"}

    result = db["cards"].insert_one(card_dict)
    return {"id": str(result.inserted_id), **card_dict}

@app.get("/get_card")                                       # Karte abrufen
def get_card(id: str):
    card_dict = db["cards"].find_one({"_id": ObjectId(id)})
    if card_dict:
        card_dict["_id"] = str(card["_id"])
        return card_dict
    return {"error": "Card not found"}

@app.get("/get_collection")                                 # Collection abrufen
def get_collection(collection_name: str):
    data = []
    for doc in db[collection_name].find():
        doc["_id"] = str(doc["_id"])
        data.append(doc)
    return data

if __name__ == "__main__":                                  # 
    import uvicorn
    uvicorn.run("api:app", host="0.0.0.0", port=8008)