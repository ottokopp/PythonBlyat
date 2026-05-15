import requests

ip_adress = "89.167.67.212"
port = "8008"

def test_health():
    response = requests.get(f"http://{ip_adress}:{port}/health")
    print(response.json())

def add_user(user_dict):
    response = requests.post(f"http://{ip_adress}:{port}/add_user", json=user_dict)
    print(response.json())

def get_user(name):
    response = requests.get(f"http://{ip_adress}:{port}/get_user", params={"name": name})
    print(response.json())

if __name__ == "__main__":
    get_user("testtest")