# SwiftUI 4-Card Deck Swipe

A focused SwiftUI interaction demo showing a 4-card stack with a staged right swipe: the previous card escapes from behind the deck, clears the edge, and only then takes the front position.

![Demo](Media/demo.gif)

## Why It Feels Good

- The right swipe is not a mirrored version of the left swipe.
- Occlusion stays believable while the previous card escapes from behind the stack.
- The `zIndex` handoff is controlled so the incoming card does not pop through too early.
- The transition starts from the live drag state, so there is no visual pop when the gesture commits.

## Where To Look

- `CardDeckPicker/CardDeckPickerView.swift` - gesture handling, card state, overlays, and transition choreography.
- `CardDeckPicker/DemoCard.swift` - the four demo items and preview image names.

## Real App Context

This interaction comes from [Palabros](https://apps.apple.com/es/app/palabros-diccionario/id6758098070), a beautifully designed dictionary and vocabulary app that helps you understand complex words, save the ones you want to remember, and learn them over time.

One important implementation detail from the real app: the actual icon change has to be deferred until leaving the Appearance flow. Applying it during the interaction triggers system UI that interrupts the animation and breaks the physical feel of the deck.

## Run Locally

Open `CardDeckPicker.xcworkspace` and run the `CardDeckPicker` scheme in Simulator.

```bash
xcodebuild -workspace "CardDeckPicker.xcworkspace" -scheme "CardDeckPicker" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
```
