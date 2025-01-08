#!/bin/bash

# Prompt for the sudo password upfront and keep sudo alive
sudo -v
while true; do
  sudo -n true
  sleep 60
done &>/dev/null &

#--------------------------------------------------
# Install essential terminal tools
#--------------------------------------------------
# Batch install essential packages with improved error handling
sudo apt update && sudo apt upgrade -y
sudo apt install -y nala apt-transport-https curl cargo ca-certificates || {
  echo "Error: Failed to install essential packages. Exiting..."
  exit 1
}

# Use Nala for batch installation of command-line tools
echo "Installing command-line tools with Nala..."
# Define the list of packages to install
packages=(
  apt-transport-https
  psmisc
  fonts-noto-color-emoji
  htop
  neofetch
  ncdu
  tree
  fzf
  ripgrep
  bat
  eza
  exa
  fd-find
  nmap
  python3
  python3-pip
  pipx
  xsel
  zip
  git
  pkg-config
)

# Loop through each package and attempt to install it
for package in "${packages[@]}"; do
  if ! sudo nala install -y "$package"; then
    echo "Failed to install $package. Continuing with the next package..."
  fi
done

# Install Nvim Appimage + LazyvimIDE
echo "Installing NeoVIM + LazyVIM..."
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

#--------------------------------------------------
#Install Docker
#--------------------------------------------------
echo "Do you want to install Docker? (yes/no)"
read -t 10 install_docker_answer || echo "Skipping Docker installation due to no response."

if [[ "$install_docker_answer" == "yes" ]]; then
  echo "Which system are you installing Docker on?"
  echo "1. Ubuntu"
  echo "2. Ubuntu distro ex: Linux Mint"
  echo "3. Debian"
  read os_choice

  # Cleanup before Docker installation
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg
  done

  if [[ "$os_choice" == "1" ]]; then
    # Docker installation commands for Ubuntu
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME_CODENAME") stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [[ "$os_choice" == "2" ]]; then
    # Docker installation commands for Ubuntu distro ex: Linux Mint
    sudo apt-get update
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [[ "$os_choice" == "3" ]]; then
    # Docker installation commands for Debian
    sudo apt-get update
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    echo "Invalid option. Exiting..."
    exit 1
  fi

  # Post-installation steps to use Docker as a non-root user (optional for both Ubuntu and Debian)
  sudo usermod -aG docker $USER

  echo "Docker installed successfully."
else
  echo "Docker installation skipped."
fi

#--------------------------------------------------
# Install Topgrade
#--------------------------------------------------
echo "Do you want to install Topgrade? (yes/no)"
read -t 10 install_topgrade_answer || echo "Skipping Topgrade installation due to no response."

if [[ "$install_topgrade_answer" == "yes" ]]; then
  echo "Installing Topgrade..."

  # Check if rustc is installed and remove it if necessary
  if which rustc >/dev/null; then
    echo "Rustc is installed. Removing it..."
    sudo nala remove rustc -y
  else
    echo "Rustc is not installed. Proceeding..."
  fi

  sudo nala install cargo -y
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
  rustup install 1.79.0
  rustup default 1.79.0
  cargo install topgrade
  export PATH=$PATH:/home/$USER/.cargo/bin
  echo "export PATH=\$PATH:/home/\$USER/.cargo/bin" >>~/.zshrc
  echo "Topgrade installed successfully."
else
  echo "Topgrade installation skipped."
fi

#
#----------------------------------------------------------------
# Install Zsh-Oh-My-Zsh, add Alias,Function and NerdFont
#-----------------------------------------------------------------
echo "Installing Zsh and Oh-My-Zsh..."

OS="$(uname)"
if [[ "$OS" == "Linux" ]] || [[ "$OS" == "Darwin" ]]; then
  echo

  if [[ "$OS" == "Linux" ]]; then
    echo -e "Installing zsh, bat, and git"
    sudo nala install zsh bat git -y &>/dev/null
  fi

  if [[ "$OS" == "Darwin" ]]; then
    echo "→ When prompted for the password, enter your Mac login password."
    if [[ ! -e "/Library/Developer/CommandLineTools/usr/bin/git" ]]; then
      sudo /usr/sbin/softwareupdate -i "$(softwareupdate -l |
        grep -B 1 -E 'Command Line Tools' |
        awk -F'*' '/^ *\\*/ {print $2}' |
        sed -e 's/^ *Label: //' -e 's/^ *//' |
        sort -V |
        tail -n1)" &>/dev/null
      sudo /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools &>/dev/null
    fi
  fi

  echo -e "Shell Configurations"
  if [[ "$OS" == "Darwin" ]]; then
    chsh -s /bin/zsh &>/dev/null
  fi
  if [[ "$OS" == "Linux" ]]; then
    sudo usermod -s /usr/bin/zsh $(whoami) &>/dev/null
    sudo usermod -s /usr/bin/zsh root &>/dev/null
  fi
  if mv -n ~/.zshrc ~/.zshrc-backup-$(date +"%Y-%m-%d") &>/dev/null; then
    echo -e " → Backing up the current .zshrc config to .zshrc-backup-date"
  fi
  (cd ~/ && curl -O https://raw.githubusercontent.com/gustavohellwig/gh-zsh/main/.zshrc) &>/dev/null
  echo "source \$HOME/.zsh/powerlevel10k/powerlevel10k.zsh-theme" >>~/.zshrc
  echo "source \$HOME/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" >>~/.zshrc
  echo "source \$HOME/.zsh/completion.zsh" >>~/.zshrc
  echo "source \$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" >>~/.zshrc
  echo "source \$HOME/.zsh/history.zsh" >>~/.zshrc
  echo "source \$HOME/.zsh/key-bindings.zsh" >>~/.zshrc

  # Theme Installation

  echo "Theme Installation"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.zsh/powerlevel10k &>/dev/null
  (cd ~/ && curl -O https://raw.githubusercontent.com/gustavohellwig/gh-zsh/main/.p10k.zsh) &>/dev/null

  # Plugins Installations

  echo "Plugins Installations"
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ~/.zsh/fast-syntax-highlighting &>/dev/null
  git clone https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/zsh-autosuggestions &>/dev/null
  (cd ~/.zsh/ && curl -O https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/lib/completion.zsh) &>/dev/null
  (cd ~/.zsh/ && curl -O https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/lib/history.zsh) &>/dev/null
  (cd ~/.zsh/ && curl -O https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/lib/key-bindings.zsh) &>/dev/null

  if [[ "$OS" == "Linux" ]]; then
    sudo cp -r /home/"$(whoami)"/.zshrc /root/
    sudo cp -r /home/"$(whoami)"/.zsh /root/
    sudo cp -r /home/"$(whoami)"/.p10k.zsh /root
  fi

  echo -e "Installation Finished"
  echo -e "You may need to reopen the terminal if the theme doesn't load automatically."

  # Ensure the ~/.zsh directory exists
  mkdir -p $HOME/.zsh

  # Install Plugins: z sudo
  echo "Installing z plugin..."
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/z/z.plugin.zsh -o $HOME/.zsh/z.plugin.zsh
  echo "source $HOME/.zsh/z.plugin.zsh" >>$HOME/.zshrc

  echo -"Installing sudo plugin..."
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh -o $HOME/.zsh/sudo.plugin.zsh
  echo "source $HOME/.zsh/sudo.plugin.zsh" >>$HOME/.zshrc

  echo "Zsh plugin installation complete!"

  echo "Setting up zsh profile"
  curl -fsSl https://raw.githubusercontent.com/EXERCISE12/Linux2.24/main/config/zshrc -o $HOME/.zshrc


fi

#--------------------------------------------------
# Installing fonts
#--------------------------------------------------
echo "Installing Font Awesome"
sudo nala install -y fonts-font-awesome

echo "Installing Cascadia Cove Nerd Font and setting up as default font for terminator"

# Create a directory for local fonts if it doesn't exist
mkdir -p ~/.local/share/fonts
# Download Cascadia Cove Nerd Font
wget -O ~/cascadia-code-nerd-font.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/CascadiaCode.zip
# Unzip the font files to the local fonts directory
unzip ~/cascadia-code-nerd-font.zip -d ~/.local/share/fonts
# Remove the downloaded zip file
rm ~/cascadia-code-nerd-font.zip

#Terminator various configuration
echo "Installing and Config Terminator Theme"
mkdir -p ~/.config/terminator/
curl -fsSL https://raw.githubusercontent.com/EXERCISE12/Linux2.24/main/config/terminator/config -o $HOME/.config/terminator/config

# Refresh the font cache
fc-cache -fv
sed -i '/^\[\[default\]\]/!b;n;s/font = .*/font = Cascadia Code 13/' ~/.config/terminator/config

echo "Cascadia Cove Nerd Font installed successfully."

# Reload Zsh shell to apply changes
echo "Reloading Zsh shell to apply changes..."
exec zsh

echo "Installation and configuratiom complete!"
