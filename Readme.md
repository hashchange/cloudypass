# Cloudypass

**DIY Cloud Sync for Keepass**

Out of the box, Keepass doesn't synchronize its data across multiple devices. Cloudypass is a set of scripts which take care of that. 

##### What does it do?

Cloudypass is a connecting layer for making the synchronization work. You provide the parts: 

- a local Keepass install on each machine, 
- a local `.kdbx` database file, or perhaps several of them,
- a way to synchronize files across devices, using a cloud service like Dropbox or a "cloud-free" mechanism like [Syncthing](https://syncthing.net/). The choice is yours. 

Cloudypass serves as the glue between these parts.

You set up Cloudypass in the local directory where you keep your `.kdbx` file(s), e.g. `C:\Users\MyUserName\Documents\Keepass`.

Next, you tell Cloudypass which directory to use for synchronization, e.g. `D:\Dropox\Keepass Sync`. The directory must be different from the one where you keep your `.kdbx` files. The local database is indeed strictly local, i.e. it must remain _outside_ of the cloud sync directory.

Whenever you edit a local database, Cloudypass copies it to the sync directory. Cloudypass also monitors the sync directory for changes made on another machine. Edits made elsewhere are merged into your local database.

That is the basic pattern. Under the hood, a few additional steps are taken. They protect the local database against file corruption from a botched network transfer. They also allow for near-simultaneous edits on more than one computer.

##### What about mobile?

Cloudypass extends the functionality of Keepass. Just like Keepass, it runs on Windows, and that is the end of it. That said, mobile clients tie in nicely with such a setup. Personally, I use [Keepassium](https://keepassium.com/), but others should work just fine, too.

Mobile clients usually check if the Keepass database on the mobile device is up-to-date when you access it, and download the most recent version from the cloud if necessary. When you edit password entries on your mobile device, the updated database is saved back to the cloud. Windows clients running Cloudypass pick up these changes and merge them into their local databases.

##### Is it safe?

I have written these scripts for my own use. They are tried and tested, in particular with my own setup – Dropbox, Boxcryptor, Keepassium on mobile –, and designed to be reliable. If things go wrong, as they eventually always do, the scripts don't fail silently, but make a fuss. Decent error handling and notifications are part of the package.

That said, Cloudypass basically just copies files around and orchestrates the process. The actual synchronization across a network is done by a service of your choice (e.g. Dropbox). Merging data from another machine into the local Keepass database is handled by Keepass itself. The scripts don't touch, know or care about passwords and keyfiles. (Keyfiles should not be synchronized anyway. If you need to move them to a new machine, do it manually.) There is little which could go wrong, security-wise, because the scope of the scripts is so limited.

Finally, there is the question of trust and transparency. The code can easily be audited by anyone. It is not compiled, so you can just read the source code, beforehand and in place on your own machine, and what you see is what you get. Cloudypass consists of Bash scripts, an extremely widespread way of automating stuff in the IT world. Plenty of people should be able to judge for themselves what the scripts do. Comments guide you through them, so if you know a bit about Bash, it is easy to make sense of the scripts.

##### What you should know up front

Setup is not a matter of a couple of quick clicks. It is easy enough, but if you have read this far, you can already guess that you need to wire a few things up yourself. The setup process requires some degree of computer literacy.

Which brings me to the important question of **support**. Feel free to raise issues and suggest improvements in the issue tracker, but please don't expect a swift (or perhaps any) response. Let me be upfront about it: I needed this thing to work for myself and put in quite a bit of effort, but I am too busy with other (non-IT) stuff to really properly run this as an open-source project. I simply lack the time.

**So here's the deal.** I have tried to provide all the info to get things going, but please don't expect any more than that. To put it bluntly, consider yourself to be on your own from here on out. Of course, you can get in touch if you run into problems, and of course I'll try to help if time allows, but please don't count on it.

If you are fine with that, here's what you need to do.

## Setup

##### What you need

- Windows 10 (most recent version) or Windows 11
- The "[Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/about)" (WSL 2) with Ubuntu Linux
  
  The Windows Subsystem for Linux is provided for free by Microsoft. It is part of Windows 10 or newer, but must be installed separately.
- Keepass 
  
  You can't use a Keepass replacement like [KeePassXC](https://keepassxc.org/), which unfortunately lacks some crucial features for this task.
- Cloudypass
- A service to synchronize files across devices, like Dropbox, iCloud, Box, Syncthing etc.

##### Wiring it up

1. Install the "Windows Subsystem for Linux" (WSL 2).

   Instructions are available [from Microsoft](https://docs.microsoft.com/en-us/windows/wsl/install) (and plenty of [other](https://ubuntu.com/tutorials/install-ubuntu-on-wsl2-on-windows-10) [sources](https://www.omgubuntu.co.uk/how-to-install-wsl2-on-windows-10)). Please make sure to 
   + install WSL 2, not the outdated version WSL 1
   + set up Ubuntu within WSL (which happens by default).
2. Install Cloudypass.

   Install it in the directory where you keep your `.kdbx` Keepass database(s). The directory containing the Cloudypass files must be named `.admin`.
   + If you are a Git user, just `cd` into the directory with your Keepass databases and run 
     
         git clone https://github.com/hashchange/cloudypass.git .admin

   + Otherwise, [download the files manually](https://github.com/hashchange/cloudypass/archive/refs/heads/master.zip) and extract the zip file in the directory with your Keepass databases.
   
   When you are done, this is what your install must look like:
   + On the top level, there is the directory containing your `.kdbx` Keepass databases. 
   + In addition to the databases, there is a subdirectory named `.admin` in it. 
   + In the `.admin` directory you'll find the Cloudypass subdirectories, like `Config`, `Trigger Definitions` etc.
   
   NB If you use more than one `.kdbx` database, they mustn't be spread out across the system. They all have to be located in the same directory. 
3. Adjust the default configuration to match your individual setup.
   + The configuration is stored in plain text files. They are located in the `.admin\Config` directory.
   + [Have a look](https://github.com/hashchange/cloudypass/blob/master/Config/sync.defaults.conf) at the default settings. They are stored in the file `sync.defaults.conf`, along with explanations. But please do not change the settings there.
   + **Rename** the file `sample.sync.conf` to `sync.conf`. Store your own settings in the `sync.conf` file.
   + You will almost certainly need to define the directory which you want to use for the cloud synchronization. If left unconfigured, Cloudypass attempts to use to the directory where Dropbox, in a standard setup, usually keeps your files: `[Your Windows user directory]\Dropbox`.
4. <a name="create-the-keepass-triggers"></a>Create the Keepass triggers.
   + [Keepass triggers](https://keepass.info/help/v2/triggers.html) are executed by Keepass, e.g. when the application is started, a database is opened or one is saved. Keepass triggers run the appropriate Cloudypass scripts.
   + Locate the file containing the Cloudypass trigger definitions:<br>
     `.admin\Trigger Definitions\sync-triggers.xml`
   + Open the file with a text editor and copy its content. 
   + Open Keepass. Access the trigger settings via the Keepass menu:<br>
     `Tools` | `Triggers...` 
   + In the trigger settings window, click on the `Tools` button and select `Paste Triggers from Clipboard`.
5. Make sure the local databases are in place.
   + If the Keepass databases are already in your local Keepass directory, you are done now. The synchronization will start by itself when you open a database. 
   + If you are connecting a new computer to an existing synchronization setup:

     Copy the `.kdbx` databases from the sync directory (the one inside Dropbox or similar) into the local directory (the one where you installed Cloudypass).
   
   In other words: Databases on your local computer will make their way to the synchronization directory by themselves. But not vice versa. Remote databases, which appear in the synchronization directory, need to be copied to the local directory by hand. They are not picked up automatically on a machine which doesn't have them yet.

## How to update

You can update with Git or by downloading and overwriting the local installation.

- If you use Git, `cd` into the `.admin` directory. A plain
  
      git pull

  will work and keep your local configuration intact.

  NB It is slightly more elegant to store your setup, including your configuration, in a private branch. You need to remove `Config/sync.conf` from `.gitignore` for that. When you update, just pull and merge the current version of Cloudypass into your private branch.

- Otherwise, [download the lastest version](https://github.com/hashchange/cloudypass/archive/refs/heads/master.zip), extract the zip file and copy its content into the `.admin` directory. Just overwrite everything that is there. Your configuration will remain intact.

You might have to **update the Keepass triggers**, too. Just remove the old ones and [recreate them](#create-the-keepass-triggers) from their new definition. Have a look at the [release notes](#release-notes) to find out if it is necessary.

## What do I do if ... ?

### Edits in a local database don't show up elsewhere

Perhaps you encounter this issue very early on. You might notice it immediately after setup if your databases on different machines are not in sync to begin with.

**Edits in a local database are pushed to the cloud and to other computers when you save the database.** They don't make it to the cloud just because the local database is somehow different from the others. You need to hit that save button.

During normal operation, pushing data when saving is exactly what should happen. But if your databases are not in sync to begin with, you need to make at least one edit in each database to bring them into the same state in every location. That will most likely happen over time, but you can bring it forward and complete the initial synchronization with a pseudo edit in each database (like adding and deleting a space, which enables you to save the database and force the data push).

Likewise, an additional save can help you if your latest edits in the local database have failed to make it to the cloud, for whatever reason. Your machine might have crashed the very moment you saved the database. Or perhaps an encryption layer like Boxcryptor has frozen and blocked the transfer. No matter what caused it: Once the problem is sorted out, just save the local database again, and your edits will be passed on to your other devices.

NB You don't need to worry about any of this in order to _receive_ edits which have been made elsewhere. They get pulled into the local database as soon as you open it. (And every time you save it, too.) There is no need to help the import along, ever.

### Sync conflict on mobile

Assume you are editing an entry in the Keepass database on your phone. Unfortunately, due to a failed sync (perhaps because of a weak signal), the file you are editing is an old one, rather than the latest version of the database. While you have been typing, the signal has come back. You are online again and hit save. 

What should you do if your mobile application, such as Keepassium, reports a conflict when you save the file?

The answer is straightforward but perhaps a little counter-intuitive: When asked, do _not_ create a separate copy, i.e. a renamed version of the database file. Instead, choose "overwrite", which replaces the version of the database in the cloud with the one you just edited on your mobile.

But what about the lost entries in the overwritten file? Well, they have vanished from the cloud copy, but not from the universe. They still exist in the local database on your computer. The next time you open it, the content of the cloud copy is imported into the local database. And the next time you edit and save it, the content of the local database is merged back into the copy in the cloud. 

The latter part is restoring the "lost" edits to the cloud copy. Everything you had overwritten previously, back then when you hit "save" on your mobile, is resurrected now. But please be aware that there may be a delay: [Only after the local database is edited and saved](#edits-in-a-local-database-dont-show-up-elsewhere), the "lost" edits will show up everywhere else again.

Details aside, the key takeaway is this: **Just overwrite conflicting files.** Your data is safe, and all will be well.

But there is one exception. For that scenario, read on.

### Synchronization troubles: Can data ever be lost?

The only way to lose data forever is when Cloudypass can't get involved.

Assume you are offline for some reason, and you edit the Keepass database on your mobile ... and a little later, still offline, on your tablet. When connectivity is restored, one of these devices will sync its database to the cloud first, followed by the other one. It is at that moment that you will see a message about a sync conflict on the device. If you decide to overwrite the copy in the cloud, the edits you made on the first device will be gone. 

The best way to handle this problem is to avoid the situation altogether: Do not edit the database on multiple mobile devices while you are offline.

(Otherwise, to preserve your edits, you would have to save a renamed copy of the file rather than overwrite the version in the cloud. That course of action contradicts what you should normally do – [see above](#sync-conflict-on-mobile). When you are back home at your computer, you would also have to [merge](https://keepass.info/help/v2/sync.html) the renamed database into your local database manually.)

That may sound complicated, but the good news is that you are unlikely to run into this issue, at least as a single user. When you are offline for an extended period of time, there probably won't be a reason for you to change entries in Keepass.

However, if a database is shared between several people and everyone edits it on the go, data loss is much more likely. Not having a signal is a frequent problem. There is a realistic chance that two people will each be working on an outdated copy at some point, without having access to each others edits. To avoid it, you have to establish a safe workflow among your group, or use a separate database for each member which is read-only for anyone but the owner.

In any event, you can't mitigate the problem with Cloudypass. The issue occurs when you use mobile devices exclusively. Cloudypass does not run on them.

### File corruption in the cloud

This has happened to me a couple of times over the years. It didn't have anything to do with Cloudypass, but that doesn't make it any less annoying. If the database in the cloud directory is corrupt, you will see an error message telling you about it.

The solution is simple: Provided that your local copy is intact, just copy it to the cloud directory, overwriting the corrupt database.

### File corruption of your local database

I have never observed this, but then again, never is a long time.

If the database in the cloud directory is still okay, you can use it to replace your local database, of course. But in case it is messed up as well, you still have another option: the backup which Cloudypass creates as part of its normal operation. 

Inside the directory with your local `.kdbx` file(s), this is where you find the backup:

    [Local .kdbx database dir]\.admin\.sync\last-known-good

You can use the file you find there to restore the local database and the cloud copy.

### Something failed without an error message

Unless things have gone wrong on a fairly fundamental level, you will see an error message – either immediately or when you close Keepass. But if that doesn't happen, you can check the error log. To display its contents, open Powershell or a Windows command prompt in the directory

    [Local .kdbx database dir]\.admin\.scripts\utils

and run the command

```bat
wsl ./show-error-log
```

It is unlikely you will ever have to access the log directly. It is located in the Linux filesystem of WSL. You can find the log file `sync.error.log` in a subdirectory of 

    ~/.local/state/cloudypass/logs

### Can Keepass databases be kept in other locations?

You can open a database in a location where Cloudypass is not installed and use it normally. There won't be any malfunctions, warnings or error messages. The database just won't be synced.

In theory, you can even set up multiple database folders, each containing a separate Cloudypass installation with its own configuration. E.g., you could use one folder for synchonization with Dropbox and another folder for synchonization with OneDrive. The Keepass triggers work for each of these installs, without duplication or adjustment. Whether anyone actually needs such a setup is debatable, but it would work.

## Background

##### Which setups has Cloudypass been tested with?

Cloudypass works in a generic way, so it should integrate with pretty much every cloud or synchronization service. But that's just theory. 

I have tested Cloudypass with these synchronisation services:

- Dropbox
- Dropbox + Boxcryptor
- iCloud
- OneDrive
- Syncthing

I have tested and used Cloudypass in conjunction with these mobile apps:

- Keepassium on iOS

If you use another sync service and are happy with the results, feel free to let me know, and I will mention it here.

##### Why WSL?

It might seem that using Bash scripts in WSL is a pretty roundabout way of automating the synchronization, and in fact it is. I simply didn't want to spend the time to get familiar with Powershell for this project. I know my way around Bash scripting, so that's what I used.

As it turned out, working with WSL [had its own set of challenges](.scripts/dev-support/Notes/Developer%20Notes.md).

If Keepass should ever be ported to macOS or its feature set is implemented in another program for the Mac, then the WSL/Bash approach will be an asset. Linux Bash scripts usually don't need much adjustment to run on a Mac.

##### Finally, I would like to thank ...

- ... the contributors to the Keepass forum who provided their thoughts [in this discussion](https://sourceforge.net/p/keepass/discussion/329220/thread/a9aab281bd/), years ago. It eventually led to this project.
- ... [the developer behind Keepass](https://keepass.info/contact.html) who put all that work into it, consistently over many years. Thank you.

## Release Notes

### v.1.1.2

- Improved error handling and logging
- Added update instructions to documentation

### v.1.1.1

You need to [reinstall the Keepass triggers](#how-to-update) when updating to this version.

- Added support for WSL distro Ubuntu 22.04 LTS
- Improved check for new errors
- Fixed optional opening of config files
- Excluded user config from being tracked by Git
- Improved documentation

### v.1.1.0

You need to [reinstall the Keepass triggers](#how-to-update) when updating to this version.

- Adjusted trigger naming conventions
- Added trigger verifying that WSL is available

### v.1.0.0

- Initial stable release

## License

MIT.

Copyright (c) 2021-2023 Michael Heim.


