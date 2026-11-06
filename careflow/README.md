# CareFlow

A Flutter application for medical triage and doctor booking.

## Setup & Running the Application

This project requires a **Groq API Key** to power the AI Chat Assistant. 

To run the application, you must supply your own Groq API key in one of two ways:

### Option 1: Run via Command Line (Recommended)
You can pass your Groq API key directly when running or building the app using the `--dart-define` flag:

```bash
flutter run --dart-define=GROQ_API_KEY=your_actual_groq_api_key_here
```

### Option 2: Use a Local `.env` File
1. In the `careflow` root folder, create a file named `.env` (you can copy `.env.example`).
2. Add your Groq API key in the following format:
   ```env
   GROQ_API_KEY=your_actual_groq_api_key_here
   ```
3. Run the app normally:
   ```bash
   flutter run
   ```

*(Note: The `.env` file is ignored by Git to keep your API key secure).*
