import requests

ip_address = "89.167.67.212"
port = "8008"
class DBHelper:
    def __init__(self):
        self.ip_address = "89.167.67.212"
        self.port = "8008"

    def test_health(self):
        response = requests.get(f"http://{ip_address}:{port}/health")
        return response

    def add_user(self, user_dict):
        response = requests.post(f"http://{ip_address}:{port}/add_user", json=user_dict)
        return response

    def get_user(self, username):
        response = requests.get(f"http://{ip_address}:{port}/get_user", params={"username": username})
        return response

if __name__ == "__main__":
    pass