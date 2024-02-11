# CHAT-NOIR

CHAT-NOIR is a chat application written in Bash and built using the OpenAI API, allowing you to have real-time conversations with an Open AI model through a command-line interface.


## Prerequisites

Before using CHAT-NOIR, ensure that you have the following prerequisites:

- `jq` installed on your system. You can check if it is already installed by running the following command:
  ```
  jq --version
  ```
  If it is not installed, follow the installation instructions specific to your operating system from the official `jq` website: https://jqlang.github.io/jq/

- A valid OpenAI API key. If you do not have one, you can sign up for an account at https://openai.com. Once you have registered and obtained the API key, keep it handy as it will be used for authentication.

## Installation

To install and run CHAT-NOIR, follow these steps:

1. Open a terminal.
2. Run the following command to download and execute the installation script:

```bash
curl -fsSL https://raw.githubusercontent.com/mattiapiccinetti/chat-noir/main/install.sh | sh
```

This command will download and run the installation script automatically. Please note that you may need to provide superuser privileges (sudo) if required by your system.

3. Once the installation is complete, you can start using CHAT-NOIR by typing `chat-noir` in your terminal.

## Usage

After launching the application and configuring a valid OpenAI API key, you will be prompted to enter your message to start the conversation.

The following commands are available:
- `/help`: Show the help menu.
- `/welcome`: Show the welcome message.
- `/config`: Show the custom configurations.
- `/set key`: Set the OpenAI API key.
- `/set model`: Set the OpenAI API model.
- `/reset key`: Reset the OpenAI API key to default.
- `/reset model`: Reset the OpenAI model to default.
- `/reset all`: Reset the configurations to default.
- `/history`: Show the conversation history.
- `/clear history`: Clear the conversation history.
- `/exit`: Exit from the application.
- `/uninstall`: Uninstall the application.

To display the list of available commands, type `/help` in the chat.

To exit the chat, simply type `/exit` or press `Ctrl + C`.

## Uninstalling CHAT-NOIR

To uninstall CHAT-NOIR follow these steps:

1. Ensure that CHAT-NOIR is currently running.
2. From within the running application, type the command "/uninstall" and press Enter.
3. Confirm the uninstallation by typing 'Y' when prompted.

## Uninstalling CHAT-NOIR (manually)

1. Locate the installation folder `chat-noir` and delete it.
2. Delete the symlink `/usr/local/bin/chat-noir`.


## License

CHAT-NOIR is open-source software released under the [GNU GPLv3](https://github.com/mattiapiccinetti/chat-noir/blob/main/LICENSE). Feel free to use, modify, and distribute it according to the terms of the license.

## Support

If you come across any problems or queries related to CHAT-NOIR, feel free to reach out to me directly. You can contact me by creating an issue on the GitHub repository. Your feedback and suggestions for enhancing the application are highly valued and appreciated.

Happy chatting!


_This README file has been generated using CHAT-NOIR._