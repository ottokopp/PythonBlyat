from server_utils.tutorial import print_sentence

menschen = [
    "Otto", 
    "Anna", 
    "Lena"
    ] # '[]' (eckige Klammern) werden benutzt für Listen. (englisch: List)

klamotten = ["Hose", "Shirt", "Jacke", "Socken", "Apfel", "Hurensohn"]

farben = ["rot", "blau", "grün"]


for mensch in menschen:
    for farbe in farben:
        for klamotte in klamotten:
            print_sentence(mensch, farbe, klamotte, verb="trägt")