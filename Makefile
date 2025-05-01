# Get the script name dynamically based on sole script in repo
SCRIPT_NAME := $(wildcard *.sh)
INSTALL_NAME := $(basename $(SCRIPT_NAME))

build:
	sudo bash $(SCRIPT_NAME) install

rebuild:
	sudo $(INSTALL_NAME) uninstall
	sudo bash $(SCRIPT_NAME) install
	
delete:
	sudo $(INSTALL_NAME) uninstall

