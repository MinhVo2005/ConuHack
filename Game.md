I want to make a 2D topdown, treasure hunting game with different environments or areas, where there would be different temperature, humidity and wind speed as well as sound and brightness. If they enter a lousy area, then there should shaking effect on the screen. If it becomes the environment is dark, then whole screen would become dark and/or blurry. There bumps in the map, some of which can contain a treasure chest. treasure chest contain random amount of gold. Make it such that character can move with their cursor. The direction in which cursor is leaning in is where the character should move. The camera view should be centered on the character.

 
Build the game for now, but later we would like integrate this game into a mobile banking app with this context: 
"""
The Chameleon’s Eye – The Interface That Adapts to Your Adventure
 
Context
Picture this: you’re an explorer on a mysterious island.
Your only tool to survive blinding beaches, booby trapped temples, and roaring jungles?
A shape shifting banking app that adapts its look, its behaviour, and even the way you interact with it—like a digital chameleon.
In real life, users deal with all kinds of situations: changing light, background noise, temporary or permanent disabilities, reduced mobility…
This challenge invites you to build a hyper inclusive, immersive, context aware banking experience.
 
Your Mission
Build an application—mobile, web, or experimental prototype—that automatically adapts its interface and interaction modes based on the user’s environment.
Your solution should demonstrate :
 
1. Visual Adaptation (Camouflage Mode)
The interface changes in response to:
•	Ambient light (day/night, too bright, too dark)
•	Noise levels (quiet vs. chaotic environment)
•	User situation (walking, standing still, busy hands)
Examples of visual adaptation:
•	Automatic theme, color, and contrast adjustments
•	Dynamic text scaling when the user approaches a critical action (transfer, balance, sensitive data)
•	Simpler layouts and fewer elements when the user is in motion
 
2. Screenless Interaction (Invisible Mode)
When the environment becomes too intense—or the user can’t look at their screen—the app switches to:
•	Voice commands
•	Simple device detectable gestures
•	Audio cues and vibration feedback
Example interactions:
•	“What’s my balance?” → Voice response + short vibration
•	Hands free transfer:
“Send 50 coins to the Savings chest” → OTP → secret phrase → gesture to confirm
•	Haptic confirmation for sensitive actions
 
3. An Immersive Voice Companion
Add a guide in full Indiana Jones spirit:
“Captain, your treasure chest holds 1,250 gold coins. The winds are in your favor today.”
Feel free to give the companion a personality, style, and humor—as long as accessibility stays at the core.
 
Sample Scenarios
•	User leaves a bustling tavern → loud environment → app switches to gesture + vibration mode
•	User enters a dark room → app activates high contrast, high readability mode
•	User has both hands busy → app switches to voice only mode
•	User suspects someone is peeking → spy mode → no text on screen
 
Suggested tech (but optional) 
•	Light / noise detection: native mobile APIs
•	Voice recognition: Web Speech API, Siri/Google frameworks, Azure Cognitive Services
•	Motion / gesture detection: gyroscope, accelerometer, hand tracking
•	Accessibility: WCAG 2.2, ARIA, dark/light mode, dynamic contrast
 
Evaluation Criteria
Projects will be judged on:
✔ Innovation
Is it surprising, clever, or something genuinely new?
✔ Context adaptation
Does the interface truly react to the user’s environment?
✔ Accessibility
Does your solution consider people with disabilities or real world constraints?
✔ Execution
A solid, functional prototype with a clear demo.
✔ Immersive experience
Sound design, visuals, storytelling—did you build a world?
"""
