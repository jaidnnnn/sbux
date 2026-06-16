import { useState } from 'react'
import Session from './components/Session'
import History from './components/History'
import { useHistory } from './useHistory'
import { useDraft } from './useDraft'

function fmtTime(iso) {
  const d = new Date(iso)
  return d.toLocaleTimeString('en-CA', { hour: '2-digit', minute: '2-digit' })
}

export default function App() {
  const [screen, setScreen] = useState('home')
  const [confirmNew, setConfirmNew] = useState(false)
  const { history, saveSession } = useHistory()
  const { draft, saveDraft, clearDraft } = useDraft()

  function handleSessionComplete(tills) {
    saveSession(tills)
    clearDraft()
    setScreen('home')
  }

  function handleStartNew() {
    if (draft) {
      setConfirmNew(true)
    } else {
      setScreen('session-new')
    }
  }

  if (screen === 'session-new' || screen === 'session-continue') {
    return (
      <Session
        initialTills={screen === 'session-continue' && draft ? draft.tills : []}
        onComplete={handleSessionComplete}
        onDraftChange={saveDraft}
        onBack={() => setScreen('home')}
      />
    )
  }

  if (screen === 'history') {
    return <History history={history} onBack={() => setScreen('home')} />
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <div className="bg-[#00704A] text-white px-4 pt-12 pb-8 text-center">
        <div className="text-4xl mb-2">☕</div>
        <h1 className="text-2xl font-bold">Till Counter</h1>
        <p className="text-white/70 text-sm mt-1">Starbucks · Canada</p>
      </div>

      <div className="flex-1 p-6 flex flex-col gap-4 max-w-md mx-auto w-full">
        {/* Continue count — shown when a draft exists */}
        {draft && (
          <button
            onClick={() => setScreen('session-continue')}
            className="w-full bg-white border-2 border-[#00704A] text-[#00704A] py-5 rounded-2xl font-bold text-lg shadow-sm active:opacity-80 text-left px-5"
          >
            <div>Continue Count</div>
            <div className="text-sm font-normal text-gray-400 mt-0.5">
              {draft.tills.length} till{draft.tills.length !== 1 ? 's' : ''} saved · last updated {fmtTime(draft.savedAt)}
            </div>
          </button>
        )}

        <button
          onClick={handleStartNew}
          className="w-full bg-[#00704A] text-white py-5 rounded-2xl font-bold text-lg shadow active:opacity-80"
        >
          Start New Count
        </button>

        <button
          onClick={() => setScreen('history')}
          className="w-full bg-white text-gray-700 py-5 rounded-2xl font-bold text-lg shadow-sm border border-gray-200 active:opacity-80"
        >
          View History
          {history.length > 0 && (
            <span className="ml-2 text-sm font-normal text-gray-400">({history.length} session{history.length !== 1 ? 's' : ''})</span>
          )}
        </button>
      </div>

      {/* Confirm discard draft modal */}
      {confirmNew && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-end">
          <div className="bg-white w-full rounded-t-3xl p-6 space-y-3">
            <h2 className="text-lg font-bold text-gray-900">Discard current count?</h2>
            <p className="text-sm text-gray-500">
              You have {draft.tills.length} till{draft.tills.length !== 1 ? 's' : ''} in progress. Starting a new count will discard them.
            </p>
            <button
              onClick={() => { clearDraft(); setConfirmNew(false); setScreen('session-new') }}
              className="w-full bg-red-500 text-white py-3 rounded-xl font-bold active:opacity-80"
            >
              Discard & Start New
            </button>
            <button
              onClick={() => setConfirmNew(false)}
              className="w-full bg-gray-100 text-gray-700 py-3 rounded-xl font-bold active:opacity-80"
            >
              Keep Current Count
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
