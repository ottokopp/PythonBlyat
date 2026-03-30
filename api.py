from pymongo import MongoClient

client = MongoClient("mongodb://116.203.251.38:27017")
db = client["testdb"]
collection = db["test"]

result = collection.insert_one({"name": "Patrick"})
print("Inserted ID:", result.inserted_id)

for doc in collection.find():
    print(doc)