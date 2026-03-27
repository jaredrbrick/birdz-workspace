# Architecture

## State Management

State is split across three layers depending on scope and persistence:

| State | Where it lives | Why |
|-------|---------------|-----|
| `activeCall` | Zustand (`useBirdSpawnStore`) | Base and Identification both need it |
| `user`, `session` | Zustand (`useAuthStore`) | Needed across the whole app |
| `base`, `progress` | Zustand (`useGameStore`) | Persisted, shared across pages |
| `hintsRevealed`, `result` | `useState` in `useIdentificationSession` | Local to one session, resets on finish |
| `selected` biome | `useState` in `WorldMap` | Local UI toggle, nothing else needs it |
| `username`, `password` | `useState` in `LoginForm` | Controlled inputs, thrown away after submit |
| spawn interval ID | `useRef` in `useBirdSpawner` | Needs to persist but must not trigger re-renders |

General rule: ephemeral UI state lives in `useState`, timers and DOM refs in `useRef`, anything shared across pages in Zustand.

## Component Structure

`Base.tsx` is the main game screen — it composes three focused child components:

```tsx
<BirdStage />        // renders the animated birds
<ProgressSidebar />  // shows score and discovered birds
<ActiveCallBanner /> // handles the call notification + countdown
```

`Identification.tsx` swaps between the guess UI and the result UI:

```tsx
{!result && <HintSystem ... />}
{!result && <BirdSearchInput ... />}
{result && <ResultFeedback ... />}
```

`App.tsx` uses guard components with early returns for auth-protected routes:

```tsx
function AuthGuard({ children }) {
  const user = useAuthStore(s => s.user)
  if (!user) return <Navigate to="/" replace />
  return children
}
```

## Data Flow

`HintSystem` receives data and a callback from `Identification.tsx` — it has no direct store access:

```tsx
<HintSystem
  bird={targetBird}
  hintsRevealed={session.hintsRevealed}
  onReveal={session.revealHint}
/>
```

`ActiveCallBanner` receives a navigation callback from `Base` — it does not know what `onListen` does:

```tsx
<ActiveCallBanner onListen={() => navigate('/app/identify')} />
```

`Navbar` skips props entirely and reads directly from Zustand:

```tsx
<Navbar />  // gets user, progress, base all from stores
```

## Custom Hooks

**`useIdentificationSession`** — bundles the entire quiz session (target bird, hints, attempts, result) so `Identification.tsx` stays declarative:

```tsx
const { targetBird, result, hintsRevealed, submitGuess, giveUp, finish } = useIdentificationSession()
```

**`useBirdSpawner`** — encapsulates the game loop (spawning, calling, cleanup). One line in `Base.tsx` starts everything:

```tsx
useBirdSpawner(base?.biomeId)
```

It uses a `useRef` for the interval ID so updating it does not trigger a re-render and restart the loop:

```tsx
const spawnTimerRef = useRef<ReturnType<typeof setInterval> | null>(null)
spawnTimerRef.current = setInterval(trySpawn, baseInterval)
```

## Key Effects

**App hydration** — loads game state from localStorage after login:

```tsx
useEffect(() => {
  if (user) hydrate(user.id)
}, [user?.id])
```

**Game loop lifecycle** — starts on mount, cleans up on unmount:

```tsx
useEffect(() => {
  spawnTimerRef.current = setInterval(trySpawn, baseInterval)
  return () => {
    clearInterval(spawnTimerRef.current)
    clearSpawns()
  }
}, [biomeId])
```

**Call countdown** — resets whenever a new call starts:

```tsx
useEffect(() => {
  if (!activeCall) return
  setElapsed(0)
  const interval = setInterval(() => { /* tick */ }, 100)
  return () => clearInterval(interval)
}, [activeCall?.instanceId])
```
