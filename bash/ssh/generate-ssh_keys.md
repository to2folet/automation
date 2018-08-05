##Generating a new ssh-key

Open Terminal.
Paste the text below, substituting in your GitHub email address.

`ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`

### This creates a new ssh key, using the provided email as a label
`Generating public/private rsa key pair.`

1. When you're prompted to `Enter a file in which to save the key` press `Enter` to accept the default file location.

Enter a file in which to save the key:

`(/Users/you/.ssh/id_rsa): [Press enter]`


At the prompt, type a secure passphrase.

`Enter passphrase (empty for no passphrase): [Type a passphrase]`

`Enter same passphrase again: [Type passphrase again]`


Adding your SSH key to the ssh-agent
------------------------------------
Before adding a new SSH key to the ssh-agent, you should have checked for existing SSH keys and generated a new SSH key.

Ensure ssh-agent is enabled:
### start the ssh-agent in the background
`eval "$(ssh-agent -s)"` 

_Agent pid 59566_



#### Add your SSH key to the ssh-agent. If you used an existing SSH key rather than generating a new SSH key, you'll need to replace id_rsa in the command with the name of your existing private key file.
`$ ssh-add ~/.ssh/id_rsa`
