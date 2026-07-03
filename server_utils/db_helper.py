import requests

class DBHelper:
    def __init__(self):
        self.ip_address = "89.167.67.212"
        self.port = "8008"

    def test_health(self):
        response = requests.get(f"http://{self.ip_address}:{self.port}/health")
        return response

    def add_user(self, user_dict):
        response = requests.post(f"http://{self.ip_address}:{self.port}/add_user", json=user_dict)
        return response

    def get_user(self, username):
        response = requests.get(f"http://{self.ip_address}:{self.port}/get_user", params={"username": username})
        return response

    def add_card(self, card_dict):
        response = requests.post(f"http://{self.ip_address}:{self.port}/add_card", json=card_dict)
        return response

    def get_card(self, id):
        response = requests.get(f"http://{self.ip_address}:{self.port}/get_card", params={"id": id})
        return response        

if __name__ == "__main__":
    db_helper = DBHelper()
    response = db_helper.add_card({"name": "Test Card"})
    print(response.status_code)
    print(response.json())