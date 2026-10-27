# Mes Dépenses — Android hors ligne

Flutter + SQLite. Secteurs : Agricole, Magasin, Atelier, Autre.

## Compilation sur GitHub Actions

Le dépôt GitHub doit contenir à la racine `pubspec.yaml`, `lib/main.dart`, `lib/database.dart`, `.github/workflows/apk.yml`.

Sur un téléphone, GitHub ne décompresse pas automatiquement un ZIP dans un dépôt. Créer un dépôt privé sur github.com, puis y créer/charger ces quatre fichiers en respectant les dossiers (Chrome > Version pour ordinateur si nécessaire). Une autre solution est d'utiliser un service Git qui sait importer un ZIP en conservant l'arborescence.

Dans le dépôt : onglet Actions > Construire APK Android > Run workflow. Attendre la fin, ouvrir l'exécution et télécharger l'artefact « Mes-Depenses-Android-APK » (ZIP contenant app-release.apk). Extraire ce ZIP et ouvrir app-release.apk sur Android.

La compilation cloud nécessite Internet; l'utilisation de l'application est hors ligne.

## Notes

APK non compilé ni testé ici. GitHub Actions peut demander d'activer les workflows. Les minutes et le stockage GitHub Actions dépendent des conditions du compte. L'APK utilise la signature de débogage générée par Flutter pour le build release par défaut : pour publier ou distribuer durablement, configurer une clé de signature propre et la conserver.
