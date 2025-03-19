# AutoGitHub

A utility for automatically creating commits in a GitHub repository based on configurable settings.

## Overview
AutoGitHub automatically generates random commits to keep your GitHub contribution graph active. It tracks the last update to ensure it only runs once per day.

## Setup Instructions

1. Clone this repository:
    ```bash
    git clone https://github.com/YourUsername/AutoGitHub.git
    cd AutoGitHub
    ```

2. Configure your GitHub repository:
    - Edit `config/settings.bat` with your GitHub repository URL
    - Customize commit settings if needed

3. Run the application:
    ```bash
    run.bat
    ```

## Features
- Configurable number of random commits
- Date tracking to prevent multiple runs per day
- Automatic repository initialization
- Customizable commit messages

## Configuration
All settings can be adjusted in the `config/settings.bat` file.

## License
MIT