

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

from fsrs import Scheduler, Card, Rating, ReviewLog
from datetime import datetime, timezone  
import time

class CustomCard(Card):
    def __init__(self, question, answer):
        super().__init__() 
        self.question = question
        self.answer = answer

    def to_dict(self):
        return {
            'question': self.question,
            'answer': self.answer,
            'card_type': self.__class__.__name__,
            'due': self.due,
            'stability': self.stability,
            'difficulty': self.difficulty,
            'reps': self.reps if hasattr(self, 'reps') else 0,
            'lapses': self.lapses if hasattr(self, 'lapses') else 0,
            'state': self.state,
            'last_review': self.last_review.isoformat() if self.last_review else None #Isoformat macht aus date String, weil sonst cancer
        }
    
class MultipleChoiceCard(CustomCard):
    def __init__(self, question, answer):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration

class CodeCard(CustomCard):
     def __init__(self, question, answer):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration

class SimpleCard(CustomCard):
    def __init__(self, question, answer):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration

    def __repr__(self):
        return f"SimpleCard(question='{self.question}',answer='{self.answer}', stability={self.stability})" #ist stablity funktion aus fsrs




class Reviewer:
    def __init__(self):
        self.scheduler = Scheduler()
        self.review_history = []
        self.total_reviews = 0 
    
    def time_dependend_rating(self, answer_time_seconds):
        if answer_time_seconds <= 5:
            return Rating.Easy    
        elif answer_time_seconds <= 10:
            return Rating.Good    
        elif answer_time_seconds <= 60:
            return Rating.Hard     
        else:
            return Rating.Again

    def review(self, card, user_answer, answer_time_seconds):
        if user_answer != card.answer:
            rating = Rating.Again
        else:
            rating = self.time_dependend_rating(answer_time_seconds)

        now = datetime.now(timezone.utc)

        reviewed_card, log = self.scheduler.review_card(card, rating, now)

        #history log
        self.review_history.append(log)
        self.total_reviews += 1

        return reviewed_card, log

reviewer = Reviewer()
karte = SimpleCard("Größte Stadt Kasachstans", "Almaty")

start_time = time.time()
print(f"FRAGE: {karte.question}")
user_answer = input("Deine Antwort: ")
antwortdauer = time.time() - start_time

# Review durchführen
neue_karte, log = reviewer.review(karte, user_answer, antwortdauer)

print("Attribute der neuen Karte:")
print(dir(neue_karte))

#to_dict() test test 
test_dict = neue_karte.to_dict()
print(test_dict['question'])    
print(test_dict['answer'])      
print("Stability:", test_dict['stability'])    
print("Due:", test_dict['due'])   


print(neue_karte)
print(f"Rating: {log.rating.name}")  

#TODO to_dict() und customtodict()
print(f"Nächster Review der Karte: {neue_karte.due}") #due ist wann man wieder karte lernen soll
#print(f"Nächster Review in: {log.scheduled_days} Days")