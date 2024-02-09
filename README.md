# CHAT-NOIR

CHAT-NOIR is a command-line chat application for OpenAI written in Bash. It allows you to engage in conversations with an AI model and get responses in real-time.

## Installation

To install and run CHAT-NOIR, follow these steps:

1. Open a terminal.
2. Run the following command to download and execute the installation script:

```bash
curl -sS https://raw.githubusercontent.com/mattiapiccinetti/chat-noir/main/install.sh | sh
```

This command will download and run the installation script automatically. Please note that you may need to provide superuser privileges (sudo) if required by your system.

3. Once the installation is complete, you can start using CHAT-NOIR by typing `chat-noir` in your terminal.

## Usage

CHAT-NOIR provides a simple and intuitive interface to communicate with the OpenAI model. After launching the application, you will be prompted to enter your message. The AI model will analyze your input and generate a response. The conversation can continue by alternating between user messages and AI responses.

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

To display the list of available commands, type `/help` in the chat.

To exit the chat, simply type `/exit` or press `Ctrl + C`.

## Developer Notes

If you wish to contribute to CHAT-NOIR or modify its code, here are a few notes to get you started:

- The source code is available on [GitHub](https://github.com/mattiapiccinetti/chat-noir).
- The application is written in Bash and uses the OpenAI API to interact with the AI model.
- It leverages the `curl` command to make API requests and process the model responses.
- The installation script takes care of dependencies and sets up the environment.

## License

CHAT-NOIR is open-source software released under the [MIT License](https://github.com/mattiapiccinetti/chat-noir/blob/main/LICENSE). Feel free to use, modify, and distribute it according to the terms of the license.

## Support

If you encounter any issues or have any questions regarding CHAT-NOIR, please create an issue on the [GitHub repository](https://github.com/mattiapiccinetti/chat-noir/issues). We appreciate any feedback and suggestions for improvement.

Happy chatting!


_This README file has been generated using CHAT-NOIR._