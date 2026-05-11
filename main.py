

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
print("Import erfolgreich!")
from datetime import datetime, timezone  
import time
from abc import ABC, abstractmethod


class CustomCard(FSRSCard):

    #TODO self.override_review_params ={"review_time", ... "} zusätzlicher Parameter für Zeit bei Karten

    def __init__(self, question, answer):
        super().__init__() 
        self.question = question
        self.answer = answer

    @abstractmethod
    def check_answer(self, user_input: Any) -> bool:
        #Chek _answer muss mit Liste oder Int oder String gebaut werden
        pass

    @abstractmethod
    def display_question(self) -> str:
        #wichtig bei MulitpleChosie Card wegen Optionen
        pass

    def to_dict(self):
        return {
            'question': self.question,
            'answer': self.answer,
            'card_type': self.__class__.__name__,
            'due': self.due,
            'stability': self.stability,
            'difficulty': self.difficulty,
            #reps ist wie oft habe ich die Karte wiederholt und lapses wie oft vergessen. Beide fangen bei 0 an zu zählen.
            'reps': self.reps if hasattr(self, 'reps') else 0,
            'lapses': self.lapses if hasattr(self, 'lapses') else 0,
            'state': self.state,
            'last_review': self.last_review.isoformat() if self.last_review else None #Isoformat macht aus date String, weil sonst cancer
        }

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


class User:
        
    def __init__(self, username: str, email: str = None):

        #UserAtrributis
        self.username = username
        self.useremail = email
        self.created_at = datetime.now(timezone.utc)

        #später umschreiben in decks
        self.cards = []
        self.reviewer = Reviewer()  # Jeder User hat seinen eigenen Reviewer
        self.stats = {"total": 0, "correct": 0}

        #Statistik für spätere Auswertungen
        self.total_reviews = 0
        self.correct_reviews = 0


    def add_card(self, card):
        self.cards.append(card)

    def remove_card(self, card):
        #TODO wenn es eine Add card gibt muss es wahrscheinlich auch eine remove card geben
        return 

    def add_deck(self, deck_name: str):
        return deck_name
    
    def get_due_cards(self):
        #gibt Stand jetzt alle Karten zurück
        return self.cards
    
    def update_card(self, old_card, new_card):
        for i, card in enumerate(self.cards):
            if card is old_card:
                self.cards[i] = new_card
                print("Card Update great Succseessss!")
                return True
        return False

    
    
class Session:
    #Session beginnt mit einloggen des Users.
    #Session endet mit beenden der App
    #history auswertung
    #stackausertung, volume change, öffnet settings
    #"im Besten mit abstrackten klassen arbeiten"
    def __init__(self, username: str):
        self.username = username
        self.start_time = datetime.now(timezone.utc)
        self.end_time = None
        self.is_active = True
        self.cards_reviewed: List = []
        self.tasks_started: int = 0
        self.tasks_completed: int = 0
        
        

    def start_session(user: User) -> Session:
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
        self.review_history = []
        self.total_reviews = 0 
    
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

        #history log
        self.review_history.append(log)
        self.total_reviews += 1

        return reviewed_card, log

reviewer = Reviewer()
name = input("dein Name:")
email = input("dein e-mail:")
user = User(name, email)
karte = SimpleCard("Größte Stadt Kasachstans", "Almaty")
karte2 = MultipleChoiceCard("Nachnahme des Wer Wird Milionär Hosts:", "Lauch", ["Lauch", "Hitler", "Epstein", "Diddler"])
karte3 = SimpleCard("Türkische Wort für das männliche Glied", "Yarak")

user.add_card(karte)
user.add_card(karte2)
user.add_card(karte3)
karten = user.get_due_cards()

print(f"Hallo Lord {user.username}!")

for card in user.get_due_cards():
    print(f"{card.question}")   
    # multiple-Choice-fuck
    if hasattr(card, 'options'):
        for i, option in enumerate(card.options, 1):
            print(f"  {i}. {option}")
    
    start_time = time.time()
    user_answer = input("\nDeine Antwort: ")
    antwortdauer = time.time() - start_time

    neue_karte, log = user.reviewer.review(card, user_answer, antwortdauer)
    print(neue_karte)
    print(f"Rating: {log.rating.name}")  
    print(f"Nächster Review der Karte: {neue_karte.due}")
    
    user.update_card(card, neue_karte)

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