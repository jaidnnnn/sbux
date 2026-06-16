export default function Numpad({ value, onChange, onClose, label }) {
  function press(key) {
    if (key === '⌫') {
      onChange(value.slice(0, -1))
    } else if (key === 'Done') {
      onClose()
    } else {
      if (value.length >= 4) return
      if (value === '0') return
      onChange(value + key)
    }
  }

  const keys = ['7','8','9','4','5','6','1','2','3','⌫','0','Done']

  return (
    <div className="fixed inset-0 z-50 flex flex-col justify-end" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="bg-white rounded-t-3xl shadow-2xl">
        {/* Label + current value */}
        <div className="px-6 pt-5 pb-3 border-b border-gray-100 flex items-center justify-between">
          <span className="font-semibold text-gray-700 text-base">{label}</span>
          <span className="text-3xl font-bold text-gray-900 tracking-tight min-w-[3ch] text-right">
            {value || '0'}
          </span>
        </div>

        {/* Keypad */}
        <div className="grid grid-cols-3 gap-2 p-4 pb-8">
          {keys.map(k => (
            <button
              key={k}
              onPointerDown={e => { e.preventDefault(); press(k) }}
              className={`
                py-4 rounded-2xl text-xl font-semibold active:scale-95 transition-transform select-none
                ${k === 'Done'
                  ? 'bg-[#00704A] text-white'
                  : k === '⌫'
                  ? 'bg-gray-100 text-gray-600'
                  : 'bg-gray-100 text-gray-900'}
              `}
            >
              {k}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
