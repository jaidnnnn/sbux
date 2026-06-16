function fmt(n) {
  return n.toLocaleString('en-CA', { style: 'currency', currency: 'CAD' })
}

function fmtDate(iso) {
  const d = new Date(iso)
  return d.toLocaleDateString('en-CA', { month: 'short', day: 'numeric', year: 'numeric' }) +
    ' · ' + d.toLocaleTimeString('en-CA', { hour: '2-digit', minute: '2-digit' })
}

export default function History({ history, onBack }) {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-[#00704A] text-white px-4 py-4 flex items-center gap-3 sticky top-0 z-10">
        <button onClick={onBack} className="text-white/80 hover:text-white text-xl">←</button>
        <h1 className="text-lg font-bold">History</h1>
      </div>

      <div className="p-4 space-y-4">
        {history.length === 0 && (
          <p className="text-center text-gray-400 mt-16">No sessions yet.</p>
        )}
        {history.map(session => (
          <div key={session.id} className="bg-white rounded-2xl shadow-sm p-4">
            <div className="text-xs text-gray-400 mb-3">{fmtDate(session.date)}</div>
            <div className="space-y-2">
              {session.tills.map(t => (
                <div key={t.tillNumber} className="flex items-center justify-between">
                  <span className="text-sm text-gray-700 font-medium">Till {t.tillNumber}</span>
                  <span className="text-sm text-gray-600">{fmt(t.total)}</span>
                  <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${
                    t.diff === 0
                      ? 'bg-green-100 text-green-700'
                      : t.diff < 0
                      ? 'bg-red-100 text-red-700'
                      : 'bg-yellow-100 text-yellow-700'
                  }`}>
                    {t.diff === 0 ? 'Balanced' : t.diff < 0 ? `Short ${fmt(Math.abs(t.diff))}` : `Over ${fmt(t.diff)}`}
                  </span>
                </div>
              ))}
            </div>
            <div className="mt-3 pt-3 border-t border-gray-100 flex justify-between text-sm font-semibold text-gray-700">
              <span>{session.tills.length} till{session.tills.length !== 1 ? 's' : ''}</span>
              <span>{fmt(session.tills.reduce((s, t) => s + t.total, 0))}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
