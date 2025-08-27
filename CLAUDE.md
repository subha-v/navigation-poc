- Look at the Apply Nearby Interaction Docs as necessary to build apps with navigation interaction across multiple devices. https://developer.apple.com/documentation/nearbyinteraction/
- Best practices - make sure to push to github at the end of every change you make to the codebase, like at the end of every message you send me.
- Indoor navigation for people (acting as AI Robots/)
People can download an app on their phone that trilaterates with 3-5 base stations that we (VALUENEX) set up
Their phone’s edge computing calculates the trilateration between it and the base stations and then gives the person accurate directions on where to go in the conference across multiple floors, etc.
The phone engages in a smart contract with the base station to ‘pay’ for the location data - not real money, but just showing that
Could implement more complex features, i.e. saving of paths or path optimization if a person types in what booths they want to go
I’m interested in AI in healthcare - where should I go and then the app directs them to the most relevant booth
 Ideas for the Steps of the PoC: 
Steps for the PoC
First download the floor plan of the building and then use AI to map it out and find the routes and absolute positions of 
First get our location in a building by querying from other 4 anchor phones
Maybe we can use 5 phones and then cross validate with the 5th phone
NLOS problems with the base stations
Then because we have your absolute position, we navigate from your absolute position to the desired position based on the floor plan