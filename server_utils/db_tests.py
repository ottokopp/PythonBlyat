import requests

ip_adress = "89.167.67.212"
port = "8008"

def test_health():
    response = requests.get(f"http://{ip_adress}:{port}/health")
    print(response.json())

    

if __name__ == "__main__":
    test_health()