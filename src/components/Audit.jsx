function fmt(n) {
  return n.toLocaleString('en-CA', { style: 'currency', currency: 'CAD' })
}

export default function Audit({ tills, onConfirm, onBack }) {
  const allBalanced = tills.every(t => t.diff === 0)
  const totalCounted = tills.reduce((s, t) => s + t.total, 0)
  const totalTarget = tills.length * 200
  const totalDiff = totalCounted - totalTarget

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      <div className="bg-[#00704A] text-white px-4 py-4 flex items-center gap-3 sticky top-0 z-10">
        <button onClick={onBack} className="text-white/80 hover:text-white text-xl">←</button>
        <h1 className="text-lg font-bold">Audit Check</h1>
      </div>

      <div className="p-4 space-y-3 flex-1 pb-32">
        {/* Overall banner */}
        <div className={`rounded-2xl px-5 py-4 text-center ${allBalanced ? 'bg-green-100' : 'bg-red-50'}`}>
          <div className="text-2xl font-bold text-gray-900">{fmt(totalCounted)}</div>
          <div className="text-sm text-gray-500 mt-0.5">
            Target: {fmt(totalTarget)} &nbsp;|&nbsp;
            <span className={`font-semibold ${allBalanced ? 'text-green-700' : totalDiff < 0 ? 'text-red-600' : 'text-yellow-600'}`}>
              {allBalanced
                ? 'All balanced ✓'
                : totalDiff < 0
                ? `Total short ${fmt(Math.abs(totalDiff))}`
                : `Total over ${fmt(totalDiff)}`}
            </span>
          </div>
        </div>

        {/* Per-till breakdown */}
        <div className="bg-white rounded-2xl shadow-sm divide-y divide-gray-100">
          {/* Table header */}
          <div className="flex px-4 py-2 text-xs font-bold uppercase tracking-widest text-gray-400">
            <span className="w-16">Till</span>
            <span className="flex-1 text-right">Counted</span>
            <span className="flex-1 text-right">Target</span>
            <span className="flex-1 text-right">Difference</span>
          </div>

          {tills.map(t => (
            <div key={t.tillNumber} className="flex items-center px-4 py-4">
              <span className="w-16 font-semibold text-gray-800">Till {t.tillNumber}</span>
              <span className="flex-1 text-right text-gray-700">{fmt(t.total)}</span>
              <span className="flex-1 text-right text-gray-400">$200.00</span>
              <span className={`flex-1 text-right font-semibold ${
                t.diff === 0 ? 'text-green-600' : t.diff < 0 ? 'text-red-600' : 'text-yellow-600'
              }`}>
                {t.diff === 0
                  ? '—'
                  : t.diff < 0
                  ? `-${fmt(Math.abs(t.diff))}`
                  : `+${fmt(t.diff)}`}
              </span>
            </div>
          ))}

          {/* Totals row */}
          <div className="flex items-center px-4 py-4 bg-gray-50 rounded-b-2xl">
            <span className="w-16 font-bold text-gray-900">Total</span>
            <span className="flex-1 text-right font-bold text-gray-900">{fmt(totalCounted)}</span>
            <span className="flex-1 text-right font-bold text-gray-400">{fmt(totalTarget)}</span>
            <span className={`flex-1 text-right font-bold ${
              totalDiff === 0 ? 'text-green-600' : totalDiff < 0 ? 'text-red-600' : 'text-yellow-600'
            }`}>
              {totalDiff === 0
                ? '—'
                : totalDiff < 0
                ? `-${fmt(Math.abs(totalDiff))}`
                : `+${fmt(totalDiff)}`}
            </span>
          </div>
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4">
        <button
          onClick={onConfirm}
          className="w-full bg-[#00704A] text-white py-3 rounded-xl font-bold text-base active:opacity-80"
        >
          Confirm & Save Session
        </button>
      </div>
    </div>
  )
}
