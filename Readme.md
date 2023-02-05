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

I have written these scripts for my own use. They are tried and tested, in particular with my own setup – Dropbox, Boxcryptor, Keepassium on mobile –, and designed to be reliable. If things go wrong, as they eventually always do, the scripts don't fail silently, but make a fuss. Decent error handling and notifications are an important part of the package.

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
   + If you are a Git user, just `cd` into the directory with your Keepass databases and run `git clone https://github.com/hashchange/cloudypass.git .admin`.
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
4. Create the Keepass triggers.
   + [Keepass triggers](https://keepass.info/help/v2/triggers.html) are executed by Keepass, e.g. when the application is started, a database is opened or one is saved. Keepass triggers run the appropriate Cloudypass scripts.
   + Locate the file containing the Cloudypass trigger definitions: `.admin\Trigger Definitions\sync-triggers.xml`. 
   + Open the file with a text editor and copy its content. 
   + Open Keepass. Access the trigger settings via the Keepass menu: `Tools` | `Triggers...` 
   + In the trigger settings window, click on the `Tools` button and select `Paste Triggers from Clipboard`.
5. Make sure the local databases are in place.
   + If the Keepass databases are already in your local Keepass directory, you are done now. The synchronization will start by itself when you open a database. 
   + If you are connecting a new computer to an existing synchronization setup:

     Copy the `.kdbx` databases from the sync directory (the one inside Dropbox or similar) into the local directory (the one where you installed Cloudypass).
   
   In other words: Databases on your local computer will make their way to the synchronization directory by themselves. But not vice versa. Remote databases, which appear in the synchronization directory, need to be copied to the local directory by hand. They are not picked up automatically on a machine which doesn't have them yet.

## What do I do if ... ?

### Sync conflict on mobile

Assume you are editing an entry in the Keepass database on your phone. Unfortunately, due to a failed sync (perhaps because of a weak signal), the file you are editing is an old one, rather than the latest version of the database. While you have been typing, the signal has come back. You are online again and hit save. 

What should you do if your mobile application, such as Keepassium, reports a conflict when you save the file?

The answer is straightforward but perhaps a little counter-intuitive: When asked, do _not_ create a separate copy, i.e. a renamed version of the database file. Instead, choose "overwrite", which replaces the version of the database in the cloud with the one you just edited on your mobile.

But what about the lost entries in the overwritten file? Well, they have vanished from the cloud copy, but not from the universe. They still exist in the local database on your computer. The next time you open it, the content of the local database is merged with the copy in the cloud. 

[That merge process is a two-way street](https://keepass.info/help/v2/sync.html). The edits from your phone are imported into the local database on your desktop. Likewise, the entries from your desktop are merged into the cloud copy. The latter part is restoring the "lost" edits to the cloud copy. Everything you had overwritten previously, when you hit "save" on your mobile, is resurrected now.

Long story short: **Just overwrite conflicting files.** Your data is safe, and all will be well.

### Synchronization troubles: Can data ever be lost?

The only way to lose data forever is when Cloudypass can't get involved.

Assume you are offline for some reason, and you edit the Keepass database on your mobile ... and a little later, still offline, on your tablet. When connectivity is restored, one of these devices will sync its database to the cloud first, followed by the other one. It is at that moment that you will see a message about a sync conflict. If you decide to overwrite the copy in the cloud, the edits you made on the first device will be gone. 

The best way to handle this problem is to avoid the situation altogether: Do not edit the database on multiple mobile devices while you are offline.

(Otherwise, to preserve your edits, you would have to save a renamed copy of the file, rather than overwriting the version in the cloud. That course of action contradicts everything you should normally do – [see above](#sync-conflict-on-mobile). When you are back home at your computer, you would also have to merge the renamed database into your local database manually.)

That may sound complicated, but the good news is that you are unlikely to run into this issue. When you are offline for an extended period of time, there probably won't be a reason for you to change entries in Keepass.

In any event, you can't mitigate the problem with Cloudypass. The issue occurs when you use mobile devices exclusively. Cloudypass does not run on them.

### File corruption in the cloud

This has happened to me a couple of times. It didn't have anything to do with Cloudypass, but that doesn't make it any less annoying. If the database in the cloud directory is corrupt, you will see an error message telling you about it.

The solution is simple: Provided that your local copy is intact, just copy it to the cloud directory, overwriting the corrupt database.

### File corruption of your local database

I have never observed this, but then again, never is a rather long time.

If the database in the cloud directory is still okay, you can use it to replace your local database, of course. But in case it is messed up as well, you still have another option: the backup which Cloudypass creates as part of its normal operation. 

Inside the directory with your local `.kdbx` file(s), this is where you find the backup:

    [Local .kdbx database dir]\.admin\.sync\last-known-good

You can use the file you find there to restore the local database and the cloud copy.

## Background

##### Which setups has Cloudypass been tested with?

Cloudypass has a pretty generic way of working, so it should work with pretty much every cloud or synchronization service. But that's just theory. 

I have tested Cloudypass with these synchronisation services:

- Dropbox
- Dropbox + Boxcryptor

I have tested and used Cloudypass in conjunction with these mobile apps:

- Keepassium on iOS

This is a rather short list. I had plans to do extensive testing with iCloud at the very least, but never got round to it. If you use another sync service and are happy with the results, feel free to let me know, and I will mention it here.

##### Why WSL?

It might seem that using Bash scripts in WSL is a pretty roundabout way of automating the synchronization, and in fact it is. I simply didn't want to spend the time to get familiar with Powershell for this project. I know my way around Bash scripting, so that's what I used. 

Should Keepass ever be ported to macOS, this will be an asset, as Linux Bash scripts usually don't need much adjustment to run on a Mac.

##### Finally, I would like to thank ...

- ... the contributers to the Keepass forum who provided their thoughts [in this discussion](https://sourceforge.net/p/keepass/discussion/329220/thread/a9aab281bd/), years ago. It eventually led to this project.
- ... [the developer behind Keepass](https://keepass.info/contact.html) who put all that work into it, consistently over many years. Thank you.

## Release Notes

### v.1.1.1

- Excluded user config from being tracked by Git
- Improved documentation

### v.1.1.0

- Adjusted trigger naming conventions
- Added trigger verifying that WSL is available

### v.1.0.0

- Initial stable release

## License

MIT.

Copyright (c) 2021-2023 Michael Heim.


