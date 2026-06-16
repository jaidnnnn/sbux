import { useState, useEffect } from 'react'
import TillCounter from './TillCounter'

function fmt(n) {
  return n.toLocaleString('en-CA', { style: 'currency', currency: 'CAD' })
}

export default function Session({ onComplete, onBack, initialTills = [], onDraftChange }) {
  const [tills, setTills] = useState(initialTills)
  const [counting, setCounting] = useState(null)

  useEffect(() => {
    onDraftChange(tills)
  }, [tills])

  function saveTill(data) {
    setTills(prev => {
      const existing = prev.findIndex(t => t.tillNumber === data.tillNumber)
      if (existing >= 0) {
        const updated = [...prev]
        updated[existing] = data
        return updated
      }
      return [...prev, data]
    })
    setCounting(null)
  }

  if (counting !== null) {
    return (
      <TillCounter
        tillNumber={counting}
        onSave={saveTill}
        onBack={() => setCounting(null)}
      />
    )
  }

  const nextTillNumber = tills.length + 1

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-[#00704A] text-white px-4 py-4 flex items-center gap-3 sticky top-0 z-10">
        <button onClick={onBack} className="text-white/80 hover:text-white text-xl">←</button>
        <h1 className="text-lg font-bold">Count Session</h1>
      </div>

      <div className="p-4 space-y-3 pb-36">
        {tills.map(t => (
          <button
            key={t.tillNumber}
            onClick={() => setCounting(t.tillNumber)}
            className="w-full bg-white rounded-2xl shadow-sm px-4 py-4 flex items-center justify-between active:opacity-70"
          >
            <div className="text-left">
              <div className="font-bold text-gray-900">Till {t.tillNumber}</div>
              <div className="text-sm text-gray-500">{fmt(t.total)}</div>
            </div>
            <div className={`text-sm font-semibold px-3 py-1 rounded-full ${
              t.diff === 0 ? 'bg-green-100 text-green-700'
              : t.diff < 0 ? 'bg-red-100 text-red-700'
              : 'bg-yellow-100 text-yellow-700'
            }`}>
              {t.diff === 0 ? 'Balanced' : t.diff < 0 ? `Short ${fmt(Math.abs(t.diff))}` : `Over ${fmt(t.diff)}`}
            </div>
          </button>
        ))}

        <button
          onClick={() => setCounting(nextTillNumber)}
          className="w-full border-2 border-dashed border-gray-300 rounded-2xl py-5 text-gray-500 font-semibold text-base active:opacity-70"
        >
          + Add Till {nextTillNumber}
        </button>
      </div>

      {tills.length > 0 && (
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4 space-y-2">
          <div className="flex justify-between text-sm text-gray-500 px-1">
            <span>{tills.length} till{tills.length !== 1 ? 's' : ''} counted</span>
            <span className={`font-semibold ${tills.every(t => t.diff === 0) ? 'text-green-600' : 'text-gray-700'}`}>
              Total: {fmt(tills.reduce((s, t) => s + t.total, 0))}
            </span>
          </div>
          <button
            onClick={() => onComplete(tills)}
            className="w-full bg-[#00704A] text-white py-3 rounded-xl font-bold text-base active:opacity-80"
          >
            Finish Session
          </button>
        </div>
      )}
    </div>
  )
}
