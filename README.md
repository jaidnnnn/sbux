# Till Counter App

A modern, minimalistic React Native Expo app for counting cash in store tills.

## Project Structure

```
k:\sbux\
├── src/
│   ├── components/       # Reusable UI components (future use)
│   ├── screens/          # Screen components
│   │   └── TillCounterScreen.tsx
│   ├── constants/        # Theme, colors, config
│   │   └── theme.ts
│   ├── types/           # TypeScript interfaces
│   │   └── index.ts
│   └── utils/           # Helper functions (future use)
├── assets/              # Images, fonts
├── .claude/             # Claude AI plugin settings (leave as-is)
├── App.tsx             # Entry point
└── package.json        # Dependencies
```

## Features

- **Cash denomination counting** - Count bills and coins
- **Real-time total calculation** - See the total amount as you count
- **Increment/decrement buttons** - Quick adjustments
- **Direct input** - Type counts directly
- **Reset functionality** - Clear all counts at once
- **Modern minimalistic design** - Clean, professional interface

## Running the App

```bash
# Start the development server
npm start

# Run on Android
npm run android

# Run on iOS (macOS only)
npm run ios

# Run in web browser
npm run web
```

## Next Steps

This is a boilerplate implementation. Future enhancements could include:
- Save/load cash counts
- Multiple till sessions
- Export reports
- Currency selection
- Custom denominations
- Historical tracking
