# Sugarcane Disease Classifier

The Flutter app sends images to the local prediction server at
`http://127.0.0.1:8000`.

## Run locally

From the repository root, install the Python environment once:

```powershell
.\setup.ps1
```

Start the prediction server in one terminal and leave it running:

```powershell
.\start_server.ps1
```

Then start the Flutter app from a second terminal:

```powershell
cd flutter_app
flutter run
```

The server must be running before selecting or capturing an image. Its health
endpoint is available at `http://127.0.0.1:8000/health`.

For a physical Android device, the app uses this computer's current LAN
address (`192.168.1.19`) by default. The phone and computer must be on the
same Wi-Fi network. If the computer's address changes, replace it with the
new LAN IP and rebuild/reinstall the APK:

```powershell
flutter build apk --release --dart-define=PREDICTION_SERVER_URL=http://192.168.1.19:8000
```

For an Android emulator, use `http://10.0.2.2:8000` instead:

```powershell
flutter run --dart-define=PREDICTION_SERVER_URL=http://10.0.2.2:8000
```

Before testing, start the server and verify `http://192.168.1.19:8000/health`
opens from the phone's browser. Allow Python/port 8000 through Windows
Firewall if it cannot be opened. Keep the computer and phone on the same
network; `127.0.0.1` in an installed APK refers to the phone, not the
computer.

In VS Code, run the **Run Sugarcane classifier** task to start both processes
when using an emulator or desktop.
