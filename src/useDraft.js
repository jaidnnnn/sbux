import { useState } from 'react'

const KEY = 'till_draft'

export function useDraft() {
  const [draft, setDraft] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(KEY)) || null
    } catch {
      return null
    }
  })

  function saveDraft(tills) {
    const d = { tills, savedAt: new Date().toISOString() }
    localStorage.setItem(KEY, JSON.stringify(d))
    setDraft(d)
  }

  function clearDraft() {
    localStorage.removeItem(KEY)
    setDraft(null)
  }

  return { draft, saveDraft, clearDraft }
}
