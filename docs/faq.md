# CalSync — FAQ

## Product

**What is CalSync and what problem does it solve?**
CalSync syncs Google Calendar and Outlook/Microsoft 365 when you do not have enough permissions:
* you can't register a new OAuth/Enterprise app;
* admin did not enabled OneCall, XCalsync, Power Sync, whatever sync

**Is it legal?**
The Outlook sync is done via un-documented api and **violates the Microsoft TOS**.
Also, consider that you are somehow snitching data without you sysadmin permission! 

**Which calendars does it support?**
Google Calendar (personal Gmail and Google Workspace accounts) and Microsoft Outlook (Microsoft 365 and outlook.com).

**Is the sync two-way or one-way?**
Both. You can configure each sync as two-way or one-way, and combine multiple sources into a single destination 
(many-to-one) or one source into multiple destinations (one-to-many).

**How long does it take for an event to appear on the other calendar?**
Most events are syned within 120 seconds;

**How is it different from Google's or Outlook's native import or ICS subscription?**
Native import is a one-time copy, does not let you choose which details to clone, and it is almost impossible to have notifications that just works.

**What gets synced for an event?**
You choose: the full event (title, time, description, location) or just a "Busy" block that reflects your availability without exposing details.

**Can I hide the details of my personal events on my work calendar?**
Yes. For each sync you can enable anonymization: colleagues will only see "Busy" instead of the real event title.

**Can I filter which events get synced?**
Not yet

**Does it handle recurring events and different time zones?**
Recurring evbents are treated as separate, single events

**What happens if I edit or delete an event?**
The edit or deletion is automatically propagated to the synced calendar on the next cycle.

**Could CalSync create duplicates, loops, or mess up my calendar?**
Maybe?

**Is there a limit to how many events I can sync?**
No

**Why not Power Automate?**
Because sometimes Power Automate is not available to all user accounts, specifically to external contractors on a short contract

## Setup & compatibility

**Do I need to install anything?**
Yes. 
You need
* [outlook-cli](https://github.com/yusufaltunbicak/outlook-cli) for outlook sync;
* [Google Sheet App Script](https://todo.com) to sync 
* The binary in this rpeo

**Wait, do I need to install stuyff like in the good 'ol 90s?**
Yes, there is no "As a Service" stuff at the moment. All data is on your workstation.  

**Does it work if my company blocks third-party apps?**
Yes, this is NOT a third party app. This "accrocchio" uses your personal account to let you use your personal information
And nothing is shared with anyone.

**Do I need admin permissions on my Microsoft or Google Workspace tenant?**
No, but you are probably infringing some TOS or policy.

**How long does it take to set up?**
Less than 5 minutes. 

## Privacy & security

**Is my data stored on your servers?**
Nope, everything is stored locally in your workstation

## Pricing & subscription

**How much does it cost? Is there a trial?**
It's free. But you can [buy me a beer](https://buy-me-a-beer.croccocode.com)

