# SyncFriends Enhanced for The Burning Crusade

This is a TBC backport of the _final_ release of "SyncFriends" (from Warlords of Draenor), along with tons of important bugfixes and enhancements.

It is _without a doubt_ the _best_ addon for syncing your friends lists between multiple characters, with a very nice GUI and completely reliable code! It takes all the hassle out of maintaining your friends list across all of your characters, and ensuring that they stay in perfect sync.

Your friends lists will be automatically monitored, and any addition/removal or player-note modifications will be detected and scheduled for all of your alts as well. There is fine-grained, manual control over which friends are synced (added/removed) and which are skipped. There are also nice, _optional_ features such as auto-removing people from friends while they and your current character are still in the same guild, which saves your real friends list space for other people. In short, this addon has absolutely _everything_ you could ever dream of for managing your friends lists...

Requires World of Warcraft - The Burning Crusade! (TBC 2.4.3)

_**Important: Follow the setup guide below before first usage!**_

### Installing the Addon

**Download: [SyncFriendsEnhancedTBC-master.zip](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/archive/master.zip)** (Put the inner "SyncFriends" and "!Compatibility" folders into your WoW's "Interface/AddOns" folder.)

### What's Enhanced?

1. Several [very important bugs](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/commits/master) have been fixed, to make the addon completely reliable.
2. The SyncFriends list of players is now [color-coded by action](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/commit/8315fd23c359a73371b98196fc1e3d74350619d7), making it super easy to see which people will be added, removed or skipped. (Before this enhancement, you had to constantly click each person to see what their action was set to...)
3. Complete [integration with the DoIKnowYou addon](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/commit/e54e593d5fda54db41bdb5b04fa737652480e098), letting you see your notes about people when you hover over their names in the SyncFriends GUI, which makes it super easy to decide whether you want to add or delete people. You should [download DoIKnowYou Enhanced (TBC)](https://github.com/VideoPlayerCode/DoIKnowYouEnhancedTBC), the best version of DoIKnowYou for TBC.
4. All friends list modifications now happen with [an intelligent "queueing" system](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/commit/2847cb2f4a707270e3b8efe694a9009bebbef012) that respects your server's rate-limits, and ensures that people are actually added or removed as intended, with perfect reliability.
5. The `/friend somebody` and `/removefriend somebody` slash commands are now [completely supported](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/commit/13b2ab72506eccd8f8aa40feb84242a1f034d873) and bug-free.
6. If the addon fails to add or remove somebody, you now see a [chat warning](https://github.com/VideoPlayerCode/SyncFriendsEnhancedTBC/commit/1a9243f21cbe4624059ece68c698b8f8465af24e) about that person, which helps you decide what to do... In most cases, it's because the player has deleted their character, renamed it, or changed faction. This warning helps you detect when that has happened.

### First Setup Guide and Recommendations

#### Step 1: Preparations

1. This addon won't do _anything_ until you've configured it!
2. Begin by logging into _one_ of your characters.
3. Then press Escape to open the Game Menu, and click on `Interface`, and then the `AddOns` tab, and finally click on `SyncFriends`.
4. Lastly, click on SyncFriends' `Options` tab. That's where the settings are!
5. Do _not_ touch the "Character" checkboxes. You should _only_ modify the "Global setting" checkboxes, so that identical settings are applied to _all_ of your characters automatically.
6. For your initial settings, the following is recommended:
    * **Enable** `Auto-import` (makes the addon automatically "import" the SyncFriends list into your character's friends list (adding/deleting friends) when you login, ensuring that all of your characters have the friends list that you've configured in SyncFriends).
    * **Enable** `Auto-export` (makes the addon automatically discover and save all of your new friends to its internal SyncFriends list, every time you login).
    * **Enable** `Sync notes` (ensures that all of your characters have the same "Note" saved for each friend).
    * **Enable** `Auto-forget` (automatically removes people from the SyncFriends storage when you've deleted a "marked as: remove from friends" person from _all_ of your characters/alts, thus removing clutter from your SyncFriends list).
    * **Disable** `Auto-remove guildmates` (this setting just ensures that people marked as "Add to friends" who are in your current character's guild aren't kept in your game's friends list, for as long as you and they remain in the same guild... you can use this later, but right now, I suggest that you leave this disabled for simplicity).
    * **Disable** `Auto-add alts` (will fill your friends lists with _all_ of your alts... a very bad waste of space! it's better to just manually configure your _important_ alts as "always add" in SyncFriends, such as your disenchanter and bank character... and to _manually_ friend special exceptions on your other characters, such as if your Skinner always mails materials to your Leatherworker, etc...).
7. Now log out of the character and log back into the _same_ character to make it discover your friends list. Don't do _anything_ else right now!
8. Log out of that character and log into _all_ of your other characters, to make SyncFriends discover their friends lists too, and to make SyncFriends learn the names of all of your alts!
    * While you're logging in and out, you'll see the addon already begin to add people to the friends-lists of your alts. And you may start seeing warnings about your friends list being full (The Burning Crusade supports friending up to 50 people). Do not worry about that for now! Just continue logging into all of your alts, so that SyncFriends learns about your alts and their friends lists! That's the only thing that matters right now...
    * Note: If you have multiple separate accounts, read the "Bonus: Linking Separate Account Folders" section further below, and link either the SyncFriends settings file or your whole account folders, or manually copy the settings-file back and forth, before you login to your alts on the other accounts... to make sure that all of your characters (and their friends) on _separate_ accounts are added to the _same_ config file.
9. After that whole "login/logout _all_ of your characters" process is complete, SyncFriends will have imported all of your friends from all of your characters, and has learned about the names of all of your alts!

#### Step 2: Building Your Final Friends List

1. Now it's time to configure your syncing preferences, by building your unified, final list of friends!
2. Go into the SyncFriends settings, by pressing Escape to open the Game Menu, and click on `Interface`, and then the `AddOns` tab, and finally click on `SyncFriends`.
3. You will see a long, scrollable list of all of the friends that have been imported from all of your characters. Names that appear in a slightly yellow/beige color are _your_ characters (alts), and the single name in pure green is your currently logged-in character.
    * Remember that The Burning Crusade only supports having up to 50 people on your actual in-game friends list. But this addon itself can remember an infinite amount of people. So after having imported all of your friends lists, it's very likely that your list is now too long and that all of those people won't fit on your actual in-game friends list. That's what you're going to fix now!
4. The first thing you should do is scroll through your whole list, looking for alts (yellow/beige color) and yourself (green color), and selecting each and marking them as "Action: skipping".
    * The "skipping" action basically means "ignore/do nothing with this character". Marking your alts that way means that SyncFriends won't auto-add/remove your alts from each other, since most of your alts do _not_ need to be linked to each other (and taking up friends list space). It also means that manual friending/unfriending is ignored, so that you're free to _manually_ add or delete your alts from each other's friends lists, such as your Skinner or Herbalist adding your Leatherworker or Alchemist to its friends list to easily mail yourself materials. That's the kind of special link that you _don't_ need on _all_ of your alts, but is good to have on _certain_ alts!
    * Tip: It can be very good to manually add all of your characters to your bank's friends list. That way you can easily mail items to all of your characters from your bank.
5. Next, go through your alts/yourself again and mark any super important characters (such as your Banker or Disenchanter) as "Action: addition".
    * The "addition" action means "add this to all of my friends lists on all of my characters". Marking all of your important alts that way is great, since it makes it very easy to mail items to your main "Bank" or disenchantable gear to your Disenchanter. But _only_ do this with the characters that you want to access from _all_ of your alts!
6. Lastly, go through your whole list of imported friends (the names in plain white), and start marking their "Action" as either "addition" or "removal".
    * This will tell SyncFriends to automatically add or delete that person from your friends lists.
    * Always remember that The Burning Crusade is limited to having 50 friends. So think very carefully about who you keep. Do you really need to keep that "nice, friendly, low-geared holy priest you met while leveling an alt... and who hasn't logged into the game in two months"?
    * If you're like most players, most people on your list should now be marked as "removal". Those are the people that you randomly added after some nice dungeon, but have never spoken to again. You do _not_ need them wasting a slot on your valuable 50-people friends list!
7. When you've marked everyone as either Add or Remove, it's time to _try_ your final friends list and checking if it all fits or not...
8. To trigger a syncing manually, simply press the big, fat "Sync" button in the GUI (or type `/syncfriends pool sync`). This will perform a sync and will apply any marked changes in your friends list, such as "remove" or "add". You will see your friends list change.
9. If you see _any messages_ such as "You have reached the maximum number of friends, could not add X" or any other friends-related messages, then you still have _too many people_ marked as "add". Go back to step 6 and mark _more_ people as "Action: removal", and then attempt manual syncing again.
10. When you don't see _any_ messages at all, try triggering the syncing _one final time_. If the chat box still says nothing (no friends-related messages being output), then you know that your final friends list _fits_ within the 50-people limit of The Burning Crusade, and that everything has been successfully applied to your current character. Your final friends list configuration is now complete!

#### Step 3: Syncing All Characters (First-Time Process)

1. To sync all of your alts, simply log out and log into each of your characters one by one. The syncing happens automatically at login.
2. Every time you've logged into a character, type `/syncfriends pool sync` manually into the chat box to trigger another syncing. If you don't see any messages, then everything has been successfully applied to that character and fits its friends list, and you're ready to login to the next character.
3. Repeat this for all of your characters.
4. Notes regarding this process:
    * People who have been marked as "remove" will start appearing as "Forgetting about X" when they've been deleted from your final alt that still had that person. This means that they're being deleted ("forgotten") from your SyncFriends list, so that they don't clutter your SyncFriends preferences anymore.
    * The `Auto-forget` feature sometimes (very, very rarely) messes up, such as "SyncFriends: Forgetting about X", "X removed from friends", "SyncFriends: Marking new X for addition". It's caused by a very rare timing-error in the addon, and it's too rare and convoluted to bother fixing. If you see it happening, keep an eye out for it in your chat box, and manually mark them for removal again (such as by simply typing `/removefriend theirname` to remove them from your friends and automatically marking them as "remove" in SyncFriends too... and, if you're sure you are the only character who still has them as a friend, you can also go into the SyncFriends settings and select them and pressing "Forget" to delete them immediately).

#### Step 4: Final Settings and Review

1. After you've synced your final friends list to all of your characters, you should go into the SyncFriends settings and read through your list of people one more time... If everything looks correct (no unexpected, extra entries), then you're done with your initial, big job of syncing all of your characters!
2. Next, I suggest going into the `Options` tab again, and _disabling_ the `Auto-forget` feature. It has served its purpose of automatically clearing out the massive clutter of having imported/merged all of your _old_ friends lists. But now, your final, clean list of friends is very personal and deliberately chosen. So it may be nice to still keep those people in your SyncFriends GUI (marked as "remove") if you ever decide to delete someone from your friends. That way, you can easily go back in and mark them as "add" again later, without having to attempt to remember their names manually.
3. Finish up with any other changes you want to make, and you're now _done!_ You can just play the game as usual now, and the SyncFriends addon will automatically keep track of people you add/remove from friends, and will keep all of your characters in perfect sync! Enjoy!

#### Bonus: Linking Separate Account Folders

1. If you have more than one account, and you want all characters on all of your _different_ accounts to share the same settings, then follow the instructions in [this Wowhead article](https://www.wowhead.com/guide=934/two-game-accounts-one-folder-now-with-mac). You can link either your whole account folders, or _just_ the `WTF\Account\<ACCOUNT NAME>\SavedVariables\SyncFriends.lua` settings file. The guide doesn't mention how to link individual files, but you can do a Google search for `mklink "hard link" file` if you are on Windows, or `symlink file` if you are on Mac or Linux, and you'll find different guides for that.
2. **Warning:** Read that guide very carefully, including all of the separate tags within each of the guide sections. You can completely corrupt all of your game settings if you don't follow the warnings in that guide; particularly about never idling (logging out as AFK) with multiple clients at once, or in any other way logging out multiple clients at once (because they would all write to the disk at once and would corrupt your settings files). And always ensuring that you log out your clients in the desired order (the last one logged out is the one that stores its data to disk), to avoid data loss. Personally, I have multiple accounts but almost never login more than one character (game client) at a time, so I can just play the game normally without _any_ risks at all! But if you're one of those people who frequently log into _multiple_ game clients simultaneously, then you have to be super careful.
3. **Alternative:** Instead of linking your files/folders, you may want to just manually copy `SyncFriends.lua` back and forth between your different account folders. That's definitely the safest method, since all of your account-data folders remain separated as intended by Blizzard. It would be a bit more hassle during the initial preparation steps, but after you're finished with your initial friends configuration then it should be pretty easy to maintain. Have fun!


