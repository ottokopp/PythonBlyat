from server_utils.db_helper import test_health, add_user, get_user


def print_sentence(mensch, farbe, klamotte, verb):
    print("Hurensohn")
    if klamotte == "Hose" or klamotte == "Jacke":
        print(f"{mensch} {verb} eine {farbe}e {klamotte}")
    elif klamotte == "Shirt":
        print(f"{mensch} {verb} ein {farbe}es {klamotte}")
    elif klamotte == "Socken":
        print(f"{mensch} {verb} {farbe}e {klamotte}")
    else:
        print(f"'{klamotte}' kann man nicht tragen/waschen/bügeln.")

def iteriere_objekte(menschen, farben, klamotten, verb):
    for mensch in menschen:
        for farbe in farben:
            for klamotte in klamotten:
                print_sentence(mensch, farbe, klamotte, verb)


normal_string = "Das ist ein normaler String"
raw_string = r"Das ist ein raw String" # benutzt man so gut wie immer nur für File-Pfade i.d.R. speziell auf Windows.

linux_pfad = "root/home/user/documents"
windows_pfad = r"C:\Users\Otto\Documents\_projects\pythonblyat\PythonBlyat\api.py" # \\ wird auch benutzt für sogenannte "Escape-Sequences"


menschen = [
    "Otto", 
    "Anna", 
    "Lena"
    ] # '[]' (eckige Klammern) werden benutzt für Listen. (englisch: List)

klamotten = ["Hose", "Shirt", "Jacke", "Socken", "Apfel", "Hurensohn"]

farben = ["rot", "blau", "grün"]