

'''
SRS modelliert:
Stability (S) → wie lange du etwas behältst
Difficulty (D) → wie schwer es ist
Retrievability (R) → Erinnerungswahrscheinlichkeit

Kernfunktion:
    R(t)=e^(-t/S), wobei t Zeit seit der letzten wiederholung ist.
    FSRS wählt das nächste Intervall so, dass du etwas wiederholst bevor du es vergisst

    S'=S⋅(1+e^(w3*)D^(-w4*)*S^(-w5)*(e^((1-R)⋅w6)-1))

    eigentlich 17 Parameter die alles steuern, diese werden stätig über den IFRS Optimizer angepasst

    t=-S⋅ln(Rtarget)
    
Nach einer Wiederholung wird S verändert.

Es gibt zwei Fälle:       
                          
1. man erinnert sich nicht(Again):                      2. man erinnert sich(Hard, Good, Easy)

schwere Karten (hohes D) → kleinere S                   gute Antwort → S wächst
Reset-artiges Verhalten                                 je schwerer (D hoch) → weniger Wachstum
                                                        je besser Timing (R niedrig) → mehr Wachstum


'''
from fsrs import Scheduler, Card as FSRSCard, Rating, ReviewLog
from datetime import datetime, timezone  
import time
from abc import ABC, abstractmethod
from server_utils.db_helper import DBHelper

class App():
    def __init__(self, reviewer, db_helper):
        self.current_user = None
        self.current_session = None
        self.reviewer = reviewer
        self.db_helper = db_helper

    def register_user(self, username):
        if self.db_helper.test_health().status_code == 200:
            print(str(self.db_helper.test_health()) + "Verbing war erfolgreich")
            new_user = User(username,email="afdkjdfsal@.de")
            response = self.db_helper.add_user(new_user.to_dict())
            print(response.json())
        else:
            print(self.db_helper.test_health(), "Verbingung zum server fehlgeschlagen")

    def login(self, username):
        response = self.db_helper.get_user(username)
        if response.status_code == 200:
            print(response.json())
            self.current_user = User.from_dict(response.json())

    def assign_cards_to_current_user(self):
        #TODO
        pass

class DBObject():
    #TODO: übergerodnete Parent-Klasse für alle Datenoibjeteke (User,Card, Session). ObjektID von MongoDB muss geändert werden genauso Datetimeklasse. Rekursion
    def __init__(self):
        self._id = None

    def to_dict(self):

        result ={}
  
        #brauch den fick weil strings keine isoformatfunktion haben und Python doch nicht so save ist wie alle FIkcer sagen
        for key, value in self.__dict__.items():
            if isinstance(value, datetime):
                result[key] = value.isoformat()
            elif isinstance(value, list):
                result[key] = []
                for item in value:
                    # Zuerst auf datetime prüfen!
                    if isinstance(item, datetime):
                        result[key].append(item.isoformat())
                    # Dann auf DBObject prüfen
                    elif isinstance(item, DBObject):
                        result[key].append(item.to_dict())
                    else:
                        result[key].append(item)
            else:
                result[key] = value
    
        return result

    @classmethod
    def _from_dict(cls, dict_data):
        pass

class CustomCard(DBObject, FSRSCard):

    #TODO self.override_review_params ={"review_time", ... "} zusätzlicher Parameter für Zeit bei Karten

    def __init__(self, question, answer, *args, **kwargs):
        super().__init__(*args, **kwargs) 
        self.question = question
        self.answer = answer

    @abstractmethod
    def check_answer(self, user_input) -> bool:
        #Chek _answer muss mit Liste oder Int oder String gebaut werden
        pass

    @abstractmethod
    def display_question(self) -> str:
        #wichtig bei MulitpleChosie Card wegen Optionen
        pass


    # def to_dict(self):
    #     return {
    #         "username": self.username,
    #         "email": self.useremail,
    #         "created_at": self.created_at.isoformat(),
    #         "assigned_cards": [card.to_dict() for card in self.assigned_cards],
    #         "stats": self.stats,
    #         "total_reviews": self.total_reviews,
    #         "correct_reviews": self.correct_reviews
    #     }

    #def from_dict():
    
class MultipleChoiceCard(CustomCard):
    def __init__(self, question, answer, options):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration
        self.options = options
    
    def check_answer(self, user_input):
        for i, option in enumerate(self.options):
            if self.answer == option: 
                return int(user_input) == i + 1  
        return False
    
    def display_question(self) -> str:
        options_lines = []
        for i, opt in enumerate(self.options):
            options_lines.append(f"  {i+1}. {opt}")
        
        options_text = "\n".join(options_lines)
        return f"{self.question}\n{options_text}"
    
    def __repr__(self):
        return f"SimpleCard(question='{self.question}',answer='{self.answer}', stability={self.stability})"
         
class CodeCard(CustomCard):
    def check_answer(self, user_input) -> bool:
        return user_input== self.answer
    
    def display_question(self) -> str:
        return f"Frage: {self.question}"
    
class ClozeCard(CustomCard):
    def check_answer(self, user_input) -> bool:
        return user_input== self.answer
    
    def display_question(self) -> str:
        return f"Frage: {self.question}"

class SimpleCard(CustomCard):
    def check_answer(self, user_input) -> bool:
        return user_input== self.answer
    
    def display_question(self) -> str:
        return f"Frage: {self.question}"
    
    def __repr__(self):
        return f"SimpleCard(question='{self.question}',answer='{self.answer}', stability={self.stability})" #ist stablity funktion aus fsrs


class User(DBObject):
    '''Aufgaben:
        Karten besitzen (assigned_cards)
        Statistiken haben (total_reviews, correct_reviews)
        Session-History haben (Liste alter Sessions)'''

    def __init__(self, username: str, email: str = None):
        # User Attribute
        self._id = None
        self.username = username
        self.email = email  # ← geändert von useremail zu email
        self.created_at = datetime.now(timezone.utc)

        # später umschreiben in decks
        self.assigned_cards = []
        self.stats = {"total": 0, "correct": 0}

        # Statistik für spätere Auswertungen
        self.total_reviews = 0
        self.correct_reviews = 0


    def add_card(self, card):
        self.assigned_cards.append(card)

    def remove_card(self, card):
        #TODO wenn es eine Add card gibt muss es wahrscheinlich auch eine remove card geben
        return 

    def add_deck(self, deck_name: str):
        return deck_name
    
    def get_due_cards(self):
        #gibt Stand jetzt alle Karten zurück
        return self.assigned_cards
    
    def update_card(self, old_card, new_card):
        for i, card in enumerate(self.assigned_cards):
            if card is old_card:
                self.assigned_cards[i] = new_card
                print("Card Update great Succseessss!")
                return True
        return False

    
    def to_dict(self):
        return {
            "username": self.username,
            "email": self.useremail,
            "created_at": self.created_at.isoformat(),
            "assigned_cards": [card.to_dict() for card in self.assigned_cards],
            "stats": self.stats,
            "total_reviews": self.total_reviews,
            "correct_reviews": self.correct_reviews
        }
    
    @classmethod
    def from_dict(cls, user_dict):
        user = cls(user_dict["username"], email=user_dict.get("email"))
        user.created_at = datetime.fromisoformat(user_dict["created_at"])
        user.assigned_cards = [card_dict for card_dict in user_dict.get("assigned_cards", [])]
        user.stats = user_dict.get("stats", {"total": 0, "correct": 0})
        user.total_reviews = user_dict.get("total_reviews", 0)
        user.correct_reviews = user_dict.get("correct_reviews", 0)
        return user
    #TODO: from dict und to dict als generische Klasse umbauen
    
class Session(DBObject):
    '''Aufgaben:
        Startzeit und Endzeit wissen
        Welche Karten reviewed wurden
        Welche ReviewLogs dazugehören'''
    #stackausertung, volume change, öffnet settings
    #"im Besten mit abstrackten klassen arbeiten"
    def __init__(self, username: str):
        self.username = username
        self.start_time = datetime.now(timezone.utc)
        self.end_time = None
        self.is_active = True
        self.cards_reviewed = []
        self.tasks_started: int = 0
        self.tasks_completed: int = 0
        
        

    def start_session(user: User):
        return Session(user)

    def start_task(self):
        self.tasks_started += 1
        
    def complete_task(self):
        self.tasks_completed += 1
        
    def add_card_reviewed(self, card):
        self.cards_reviewed.append(card)
        
    def end_session(self):
        self.when_exited = datetime.now(timezone.utc)

    #TODO sessiondauer und auswertung machen

class Reviewer:
    def __init__(self):
        self.scheduler = Scheduler()
    
    def time_dependent_rating(self, answer_time_seconds):
        if answer_time_seconds <= 5:
            return Rating.Easy    
        elif answer_time_seconds <= 10:
            return Rating.Good    
        elif answer_time_seconds <= 60:
            return Rating.Hard     
        else:
            return Rating.Again

    def review(self, card, user_answer, answer_time_seconds):
        if card.check_answer(user_answer):
            rating = self.time_dependent_rating(answer_time_seconds)
        else:
            rating = Rating.Again

        now = datetime.now(timezone.utc)

        reviewed_card, log = self.scheduler.review_card(card, rating, now)

        return reviewed_card, log

if __name__ == "__main__":
    r = Reviewer()
    print(r.__dict__)
    reviewer = Reviewer()
    #dbhelper = DBHelper()
    app = App(reviewer, dbhelper)

    # app.register_user("Lord Ottrick")
    # app.login("Lord Ottrick")

    # print("currently logged in user", app.current_user.to_dict()["username"])

    # # Test für DBObject.to_dict()
    # user = User("Otto", "otto@email.com")  # Nur eine User-Erstellung
    
    # # Erstelle Karten
    # karte1 = SimpleCard("Was ist 2+2?", "4")
    # karte2 = SimpleCard("Hauptstadt von Deutschland?", "Berlin")
    
    # # Füge Karten zum User hinzu
    # user.assigned_cards.append(karte1)
    # user.assigned_cards.append(karte2)
    
    # # Konvertiere zu Dictionary
    # ergebnis = user.to_dict()
    
    # print("\n--- Test von DBObject.to_dict() ---")
    # print("Username:", ergebnis["username"])
    # print("Email:", ergebnis["email"])
    # print("Anzahl Karten:", len(ergebnis["assigned_cards"]))
    # print("\nErste Karte:")
    # print("  Frage:", ergebnis["assigned_cards"][0]["question"])
    # print("  Antwort:", ergebnis["assigned_cards"][0]["answer"])
    # print("\nTyp der ersten Karte:", type(ergebnis["assigned_cards"][0]))
    
    # reviewer = Reviewer()
    # name = input("dein Name:")
    # email = input("dein e-mail:")
    # user = User(name, email)
    # karte = SimpleCard("Größte Stadt Kasachstans", "Almaty")
    # karte2 = MultipleChoiceCard("Nachnahme des Wer Wird Milionär Hosts:", "Lauch", ["Lauch", "Hitler", "Epstein", "Diddler"])
    # karte3 = SimpleCard("Türkische Wort für das männliche Glied", "Yarak")

    # user.add_card(karte)
    # user.add_card(karte2)
    # user.add_card(karte3)
    # karten = user.get_due_cards()

    # print(f"Hallo Lord {user.username}!")

    # for card in user.get_due_cards():
    #     print(f"{card.question}")   
    #     # multiple-Choice-fuck
    #     if hasattr(card, 'options'):
    #         for i, option in enumerate(card.options, 1):
    #             print(f"  {i}. {option}")
        
    #     start_time = time.time()
    #     user_answer = input("\nDeine Antwort: ")
    #     antwortdauer = time.time() - start_time

    #     neue_karte, log = user.reviewer.review(card, user_answer, antwortdauer)
    #     print(neue_karte)
    #     print(f"Rating: {log.rating.name}")  
    #     print(f"Nächster Review der Karte: {neue_karte.due}")
        
    #     user.update_card(card, neue_karte)

""" start_time = time.time()
print(f"FRAGE: {karte.question}")
user_answer = input("Deine Antwort: ")
antwortdauer = time.time() - start_time

# Review durchführen
neue_karte, log = reviewer.review(karte, user_answer, antwortdauer)

print("Attribute der neuen Karte:")
print(dir(neue_karte))

#to_dict() test test 
test_dict = neue_karte.to_dict()
print("Frage:", test_dict["question"])    
print("Antwort:", test_dict["answer"])     
print("Wiederholungen:", test_dict["reps"]) 
print("Stability:", test_dict["stability"])    
print("Due:", test_dict["due"])   


print(neue_karte)
print(f"Rating: {log.rating.name}")  
print(f"Nächster Review der Karte: {neue_karte.due}") #due ist wann man wieder karte lernen soll

karte2 = MultipleChoiceCard("Nachnahme des Wer Wird Milionär Hosts:", "Lauch", ["Lauch", "Hitler", "Epstein", "Diddler"])
start_time = time.time()
print(f"FRAGE: {karte2.question}")
print(f"FRAGE: {karte2.options}")
user_answer = input("Deine Antwort: ")
antwortdauer = time.time() - start_time

neue_karte2, log = reviewer.review(karte2, user_answer, antwortdauer)

print(neue_karte2)
print(f"Rating: {log.rating.name}")  
print(f"Nächster Review der Karte: {neue_karte2.due}") #due ist wann man wieder karte lernen soll """