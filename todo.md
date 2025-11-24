# TODO

Manual Steps I should try to automate:

# Figure out

- [ ] NVM

# Mac

- [ ] Settings -> Displays -> More Space (1800x1169)
- [ ] Launch AeroSpace
  - [ ] (Accessibility) -> AeroSpace [true]
  - [ ] (Accessibility) -> borders [true]

## Ice (window bar)

- Launch ICE.
- Grant it all the permissions.
- Start at login.
- Split mode.
- Turn on border.
  - Width: 2
  - Color: #FF9300 or rgb(255, 147, 0)
- Disable inset.
- Make sure aerospace paddings are all good.

## Linearmouse

- Launch linear mouse.
- Probably need to grant permissions while launching.
- Use these settings:
  - (most other settings should be configured via linearmouse.json)
  - General:
    - Show in menu bar
    - Start at login
    - Show in dock

## Brew Setups

`zsh-autosuggestions`

```bash
# Add to .zshrc
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
```

`zsh-syntax-highlighting`

```bash
# Add to .zshrc
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# If "highlights directory not found", try:
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=/opt/homebrew/share/zsh-syntax-highlighting/highlighters
```

`postgres`

```bash
# For compilers:
export LDFLAGS="-L/opt/homebrew/opt/postgresql@17/lib"
export CPPFLAGS="-I/opt/homebrew/opt/postgresql@17/include"

# To start service now and at login:
brew services start postgresql@17
```
