import { useState, useEffect } from 'react'

const KEY = 'till_history'

export function useHistory() {
  const [history, setHistory] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(KEY)) || []
    } catch {
      return []
    }
  })

  useEffect(() => {
    localStorage.setItem(KEY, JSON.stringify(history))
  }, [history])

  function saveSession(tills) {
    const record = {
      id: Date.now(),
      date: new Date().toISOString(),
      tills,
    }
    setHistory(prev => [record, ...prev])
    return record
  }

  function clearHistory() {
    setHistory([])
  }

  return { history, saveSession, clearHistory }
}
