# StoreKit Testing

Use Apple's local StoreKit testing flow in Xcode.

Product to create:

- Type: `Non-Consumable`
- Product ID: `io.chrismahlke.lociq.schools.unlock`
- Display name: `School Data Unlock`

Recommended local test setup:

1. In Xcode, create a new `StoreKit Configuration File`.
2. Add a non-consumable product using the product ID above.
3. Open `Product > Scheme > Edit Scheme`.
4. Under `Run > Options`, select that StoreKit configuration file.
5. Launch the app and test both locked and unlocked states.

Recommended Apple testing path after local testing:

1. Add the same product in App Store Connect.
2. Test in the App Store sandbox.
3. Validate the full flow in TestFlight.
