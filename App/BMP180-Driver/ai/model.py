import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import joblib

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, accuracy_score, precision_recall_fscore_support, confusion_matrix

from sklearn.linear_model import LogisticRegression
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.naive_bayes import GaussianNB
from sklearn.neural_network import MLPClassifier

df = pd.read_csv('./data/weather_opti_labeled.csv')

counts = df['description'].value_counts()
valid_classes = counts[counts >= 2].index

df_filtered = df[df['description'].isin(valid_classes)]

X = df_filtered[['temperature_C', 'pressure_mb']]
y = df_filtered['description']

counts = y.value_counts()
print("Phân phối class:\n", counts)

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42, stratify=y
)

scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

model_dir = './model'
os.makedirs(model_dir, exist_ok=True)

joblib.dump(scaler, os.path.join(model_dir, 'scaler.pkl'))

models = {
    'Logistic Regression': LogisticRegression(max_iter=1000, class_weight='balanced'),
    'KNN': KNeighborsClassifier(),
    'Decision Tree': DecisionTreeClassifier(),
    'Random Forest': RandomForestClassifier(class_weight='balanced'),
    'SVM': SVC(probability=True),
    'Naive Bayes': GaussianNB(),
    'Gradient Boosting': GradientBoostingClassifier(),
    'Neural Network': MLPClassifier(max_iter=1000)
}

visualize_dir = '/home/pi/Desktop/App/BMP180-Driver/visualize'
os.makedirs(visualize_dir, exist_ok=True)

with open("results.txt", "w", encoding='utf-8') as f:
    for name, model in models.items():
        f.write(f"\n🔹 Model: {name}\n")
        
        model.fit(X_train_scaled, y_train)
        
        y_pred = model.predict(X_test_scaled)

        model_filename = os.path.join(model_dir, f'{name.replace(" ", "_")}.pkl')
        joblib.dump(model, model_filename)

        acc = accuracy_score(y_test, y_pred)
        f.write(f"Accuracy: {acc:.4f}\n")

        report = classification_report(y_test, y_pred, zero_division=0)
        f.write(report)

        precision, recall, f1, _ = precision_recall_fscore_support(
            y_test, y_pred, average='weighted', zero_division=0
        )
        f.write(f"\nWeighted Precision: {precision:.4f}\n")
        f.write(f"Weighted Recall: {recall:.4f}\n")
        f.write(f"Weighted F1-score: {f1:.4f}\n")

        cm = confusion_matrix(y_test, y_pred, labels=valid_classes)
        plt.figure(figsize=(8, 6))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                    xticklabels=valid_classes, yticklabels=valid_classes)
        plt.xlabel('Predicted')
        plt.ylabel('True')
        plt.title(f'Confusion Matrix - {name}')
        plt.tight_layout()
        plt.savefig(f'{visualize_dir}/confusion_matrix_{name.replace(" ", "_")}.png')
        plt.close()

        f.write("\n" + "-"*60 + "\n")

print("✅ Hoàn thành training.")
print("📁 Kết quả lưu vào: results.txt, models/, visualize/")
