from db_helper import DBHelper

if __name__ == "__main__":
    db_helper = DBHelper()
    response = db_helper.test_health()
    print(response.status_code)
    print(response.text)