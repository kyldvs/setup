# TODO

Manual Steps I should try to automate:

# Mac

- [ ] Settings -> Displays -> More Space (1800x1169)

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
