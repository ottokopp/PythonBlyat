from pymongo import MongoClient
from fastapi import FastAPI

client = MongoClient("mongodb://116.203.251.38:27017")      # Verbindung zur MongoDB
db = client["testdb"]       
collection = db["test"]     
app = FastAPI()             

result = collection.insert_one({"name": "Patrick"})         # Dokument einfügen
print("Inserted ID:", result.inserted_id)               

for doc in collection.find():                               # Alle Dokumente abrufen
    print(doc)

@app.get("/")                                               # Root-Endpoint
def root():
    return {"message": "API läuft"}

@app.get("/add_user")                                       # Benutzer hinzufügen
def add_user(name: str):
    result = db["users"].insert_one({"name": name})
    return {"id": str(result.inserted_id), "name": name}

@app.get("/get_user")                                       # Benutzer abrufen
def get_user(name: str):
    user = db["users"].find_one({"name": name})
    if user:
        user["_id"] = str(user["_id"])
        return user
    return {"error": "User not found"}

@app.get("/add_card")                                       # Karte hinzufügen
def add_card(title: str, owner: str):
    result = db["cards"].insert_one({"title": title, "owner": owner})
    return {"id": str(result.inserted_id), "title": title, "owner": owner}

@app.get("/get_card")                                       # Karte abrufen
def get_card(title: str):
    card = db["cards"].find_one({"title": title})
    if card:
        card["_id"] = str(card["_id"])
        return card
    return {"error": "Card not found"}

@app.get("/get_collection")                                 # Collection abrufen
def get_collection(collection_name: str):
    data = []
    for doc in db[collection_name].find():
        doc["_id"] = str(doc["_id"])
        data.append(doc)
    return data