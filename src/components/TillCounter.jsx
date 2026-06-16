import { useState } from 'react'
import { DENOMINATIONS, TARGET } from '../denominations'
import Numpad from './Numpad'

function fmt(n) {
  return n.toLocaleString('en-CA', { style: 'currency', currency: 'CAD' })
}

const TABS = [
  { key: 'roll', label: 'Rolls' },
  { key: 'coin', label: 'Coins' },
  { key: 'note', label: 'Cash'  },
]

export default function TillCounter({ tillNumber, onSave, onBack }) {
  const [counts, setCounts] = useState(() =>
    Object.fromEntries(DENOMINATIONS.map(d => [d.id, '']))
  )
  const [tab, setTab] = useState('roll')
  const [active, setActive] = useState(null)

  function set(id, val) {
    setCounts(prev => ({ ...prev, [id]: val }))
  }

  const total = DENOMINATIONS.reduce((sum, d) => {
    return sum + (parseInt(counts[d.id]) || 0) * d.value
  }, 0)
  const diff = total - TARGET
  const isShort = diff < 0
  const isBalanced = diff === 0 && total > 0

  const tabItems = DENOMINATIONS.filter(d => d.type === tab)
  const activeDenom = active ? DENOMINATIONS.find(d => d.id === active) : null

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <div className="bg-[#00704A] text-white px-4 py-4 flex items-center gap-3">
        <button onClick={onBack} className="text-white/80 hover:text-white text-xl">←</button>
        <h1 className="text-lg font-bold">Till {tillNumber}</h1>
      </div>

      {/* Total box */}
      <div className={`mx-4 mt-4 rounded-2xl px-5 py-4 text-center ${isBalanced ? 'bg-green-100' : isShort && total > 0 ? 'bg-red-100' : total > TARGET ? 'bg-yellow-100' : 'bg-white'} shadow-sm`}>
        <div className="text-4xl font-bold text-gray-900 tracking-tight">{fmt(total)}</div>
        <div className="flex items-center justify-center gap-3 mt-1 text-sm">
          <span className="text-gray-400">{fmt(TARGET)}</span>
          <span className="text-gray-300">|</span>
          <span className={`font-semibold ${isBalanced ? 'text-green-600' : isShort && total > 0 ? 'text-red-600' : total > TARGET ? 'text-yellow-600' : 'text-gray-400'}`}>
            {total === 0 ? 'Not started' : isBalanced ? 'Balanced ✓' : isShort ? `Short ${fmt(Math.abs(diff))}` : `Over ${fmt(diff)}`}
          </span>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex mx-4 mt-4 bg-gray-200 rounded-xl p-1 gap-1">
        {TABS.map(t => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`flex-1 py-2 rounded-lg text-sm font-semibold transition-all ${
              tab === t.key
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Denomination list */}
      <div className="mx-4 mt-3 flex-1 bg-white rounded-2xl shadow-sm divide-y divide-gray-100 overflow-hidden mb-28">
        {tabItems.map(d => {
          const qty = parseInt(counts[d.id]) || 0
          const subtotal = qty * d.value
          return (
            <button
              key={d.id}
              onClick={() => setActive(d.id)}
              className="w-full flex items-center px-4 py-4 active:bg-gray-50 text-left"
            >
              <span className="flex-1 font-medium text-gray-800 text-base">{d.label}</span>
              {qty > 0 && (
                <span className="text-xs text-gray-400 mr-3">{fmt(subtotal)}</span>
              )}
              <span className={`w-12 text-right text-xl font-bold ${qty > 0 ? 'text-[#00704A]' : 'text-gray-200'}`}>
                {qty > 0 ? qty : '—'}
              </span>
            </button>
          )
        })}
      </div>

      {/* Save button */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4">
        <button
          onClick={() => onSave({
            tillNumber,
            counts,
            total: Math.round(total * 100) / 100,
            diff: Math.round(diff * 100) / 100,
          })}
          className="w-full bg-[#00704A] text-white py-3 rounded-xl font-bold text-base active:opacity-80"
        >
          Save Till {tillNumber}
        </button>
      </div>

      {/* Numpad */}
      {active && activeDenom && (
        <Numpad
          label={activeDenom.label}
          value={counts[active]}
          onChange={val => set(active, val)}
          onClose={() => setActive(null)}
        />
      )}
    </div>
  )
}
