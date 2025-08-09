Own Splitwise Copy 💰
A Flutter + Firebase group expense-splitting app that tracks expenses, calculates balances, and minimizes settlement transactions using a heap-based DSA approach.

Downloadable APK link for live working on your Android: https://vitacin-my.sharepoint.com/:u:/g/personal/rohit_kumar2022_vitstudent_ac_in/EZQUCCfkmmJAtmIBG09eil4BSG4mXuASGS5p8BGXCjyR9Q?e=GkQk1r

🔗 Live Demo — https://vitacin-my.sharepoint.com/:v:/g/personal/rohit_kumar2022_vitstudent_ac_in/EQd6L7nDDL9Jjl_OgkNzThUBbjF37PueeboU7ixU1yuQzw?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJTdHJlYW1XZWJBcHAiLCJyZWZlcnJhbFZpZXciOiJTaGFyZURpYWxvZy1MaW5rIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXcifX0%3D&e=qgIZ5T

🚀 Features
1. Real-time Multi-user trip expense tracking
2. Add, edit, and delete expenses
3. Shows pairwise dues between members
4. Manual settlements supported
5. Reduced transactions using greedy + priority queue
6. Optimal payer suggestion for minimal future settlements

🛠 Tech Stack
Frontend: Flutter
Backend: Firebase (Auth + Firestore)
Algorithm: Greedy + Min-Max Heap for transaction reduction

🤔How Does 'Reduced Transactions' work??
Say A --> B ₹500, B --> C ₹500 too. Normally this means 2 transactions.
However an easier work around is A paying ₹500 to C directly cutting it to just 1 transaction
When more people are involved, this optimization saves a LOT of pay-backs.

