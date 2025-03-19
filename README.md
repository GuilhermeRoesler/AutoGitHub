# AutoGitHub

![GitHub stars](https://img.shields.io/github/stars/GuilhermeRoesler/AutoGitHub?style=social)
![GitHub forks](https://img.shields.io/github/forks/GuilhermeRoesler/AutoGitHub?style=social)
![GitHub license](https://img.shields.io/github/license/GuilhermeRoesler/AutoGitHub)
![GitHub last commit](https://img.shields.io/github/last-commit/GuilhermeRoesler/AutoGitHub)

> **Seamlessly automate your GitHub contributions and keep your activity graph alive!** 🚀

## 📌 Overview
AutoGitHub is a fully automated solution for keeping your GitHub contribution graph active by generating and pushing random commits at configurable intervals. Designed for developers who want to maintain an engaging GitHub profile, AutoGitHub ensures that commits occur only once per day, preventing redundancy while keeping your profile consistently active.

### 🔥 Why Use AutoGitHub?
- **Maintains an active GitHub profile effortlessly**
- **Helps showcase continuous development activity**
- **Customizable settings to fit your workflow**
- **Fully automated with minimal setup**

## ✨ Features
✅ **Automated Commits** – Randomly generated commits based on user-defined settings.  
✅ **Daily Commit Tracking** – Ensures commits are made only once per day to prevent spam.  
✅ **Customizable Commit Messages** – Define your own commit messages to keep it authentic.  
✅ **Repository Auto-Initialization** – Detects and initializes your repository if necessary.  
✅ **Windows Startup Integration** – Option to launch AutoGitHub automatically on startup.  
✅ **Lightweight & Resource-Efficient** – Runs in the background without interfering with your workflow.

---

## 🚀 Installation & Setup

### 1️⃣ Clone the Repository
```bash
git clone https://github.com/GuilhermeRoesler/AutoGitHub.git
cd AutoGitHub
```

### 2️⃣ Configure Your Repository
Modify the configuration file to personalize AutoGitHub:
- Open `config/settings.bat`
- Set your **GitHub repository URL**
- Adjust **commit frequency** and **commit messages** as needed

### 3️⃣ Run AutoGitHub
Execute the script to start generating commits:
```bash
run.bat
```

---

## 🔄 Automating Execution on Windows Startup
To ensure AutoGitHub runs automatically every time your computer starts, follow these steps:

1. Press `Win + R`, type `shell:startup`, and hit `Enter`.
2. This will open the **Startup** folder.
3. Copy the `run.bat` file from the AutoGitHub directory.
4. Paste a **shortcut** of `run.bat` into the **Startup** folder.

🔹 **Now, AutoGitHub will execute automatically whenever you start your computer!**

---

## ⚙️ Advanced Configuration
For power users, AutoGitHub allows fine-tuned control through its `config/settings.bat` file:

### 🔧 Available Settings:
- **Repository URL** – Define the target repository.
- **Commit Frequency** – Set how often commits should be made.
- **Custom Commit Messages** – Specify a list of messages for randomized commits.
- **Branch Selection** – Choose which branch to commit to.
- **Scheduled Execution** – Configure scheduled tasks via Windows Task Scheduler for even greater control.

---

## 🖥️ Running AutoGitHub as a Background Process
For users who prefer not to run scripts manually, AutoGitHub can be set up as a Windows service or scheduled task:

### ⏳ Using Windows Task Scheduler:
1. Open **Task Scheduler** (`Win + R` → `taskschd.msc`).
2. Click **Create Basic Task** and name it `AutoGitHub`.
3. Select **Daily** and set the preferred execution time.
4. Choose **Start a Program** and browse to `run.bat` in the AutoGitHub folder.
5. Finish setup, and AutoGitHub will run automatically at the scheduled time.

---

## 📜 License
This project is licensed under the **MIT License** – you are free to use, modify, and distribute it as you like.

---

## 👨‍💻 Contributing
Contributions are welcome! If you have ideas for improvement, feel free to:
- Fork this repository and submit a pull request.
- Open an issue to suggest enhancements or report bugs.
- Share feedback to help make AutoGitHub even better.

---

## 📬 Contact & Support
Have questions or need assistance? Reach out via:
- **GitHub Issues**: [Report an Issue](https://github.com/GuilhermeRoesler/AutoGitHub/issues)
- **Email**: GuilhermeRoesler@gmail.com
- **Twitter/X**: [@GuilhermeRoesler](https://twitter.com/GuilhermeRoesler)

💡 *Boost your GitHub activity graph effortlessly with AutoGitHub!* 🚀

