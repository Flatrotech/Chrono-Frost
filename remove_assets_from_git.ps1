# PowerShell script to remove already committed assets from git tracking
# This will keep the files on your local system but tell git to stop tracking them

# Run this from your project root directory

# Remove asset files from git tracking (but keep them on disk)
git rm --cached -r assets/audio/music/*.ogg
git rm --cached -r assets/audio/music/*.ogg.import
git rm --cached -r assets/audio/sfx/*.wav
git rm --cached -r assets/audio/sfx/*.wav.import
git rm --cached -r assets/aseprite/*.aseprite
git rm --cached -r assets/aseprite/*.png
git rm --cached -r assets/aseprite/*.png.import
git rm --cached -r assets/*.png
git rm --cached -r assets/*.png.import
git rm --cached -r assets/*.aseprite

# After running this, commit the changes:
# git commit -m "Remove asset files from git tracking"

Write-Host "Asset files have been removed from git tracking."
Write-Host "Now you can commit these changes with: git commit -m 'Remove asset files from git tracking'"
