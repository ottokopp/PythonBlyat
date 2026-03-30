from fastapi import FastAPI
from pymongo import MongoClient

app = FastAPI()

client = MongoClient("mongodb://116.203.251.38:27017")
db = client["testdb"]


@app.get("/")
def root():
    return {"message": "API läuft"}


@app.get("/add_user")
def add_user(name: str):
    result = db["users"].insert_one({"name": name})
    return {"id": str(result.inserted_id), "name": name}


@app.get("/get_user")
def get_user(name: str):
    user = db["users"].find_one({"name": name})
    if user:
        user["_id"] = str(user["_id"])
        return user
    return {"error": "User not found"}


@app.get("/add_card")
def add_card(title: str, owner: str):
    result = db["cards"].insert_one({"title": title, "owner": owner})
    return {"id": str(result.inserted_id), "title": title, "owner": owner}


@app.get("/get_card")
def get_card(title: str):
    card = db["cards"].find_one({"title": title})
    if card:
        card["_id"] = str(card["_id"])
        return card
    return {"error": "Card not found"}


@app.get("/get_collection")
def get_collection(collection_name: str):
    data = []
    for doc in db[collection_name].find():
        doc["_id"] = str(doc["_id"])
        data.append(doc)
    return data