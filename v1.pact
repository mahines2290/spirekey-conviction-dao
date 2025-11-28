;; kadena-dao-voting-v1.pact
(module spirekey-dao-voting GOVERNANCE

  (defcap GOVERNANCE () (enforce false "governance disabled for prototype"))

  (defschema proposal
    id:string
    title:string
    description:string
    creator:string
    base-lock:decimal          ; minimum lock at t=0
    open-time:time
    close-time:time
    total-yes:decimal
    total-no:decimal
    total-neutral:decimal
    executed:bool
    reward-pool:decimal)       ; optional participation reward

  (defschema vote
    proposal-id:string
    voter:string
    choice:string              ; "yes" | "no" | "neutral"
    locked:decimal
    vote-time:time
    jwt:string)                ; proof of fresh biometric

  (deftable proposals:{proposal})
  (deftable votes:{vote})

  (defconst JWT_VERIFIER_KEY:string "spirekey-relay-public-ed25519-base64-here")
  (defconst VOTE_REWARD_RATE:decimal 0.003)  ; 0.3% of treasury spend as reward pool (optional)

  (defun verify-jwt-signature:string (jwt:string payload:string signature-base64:string)
    (enforce (= (ed25519-verify payload JWT_VERIFIER_KEY signature-base64) true)
             "Invalid SpireKey JWT signature"))

  (defun create-proposal:string
    ( id:string title:string description:string duration-days:integer base-lock:decimal )
    (insert proposals id {
      "id": id,
      "title": title,
      "description": description,
      "creator": (at "sender" (chain-data)),
      "base-lock": base-lock,
      "open-time": (at "block-time" (chain-data)),
      "close-time": (add-time (at "block-time" (chain-data)) (days duration-days)),
      "total-yes": 0.0,
      "total-no": 0.0,
      "total-neutral": 0.0,
      "executed": false,
      "reward-pool": 0.0
    }))

  (defun required-lock:decimal (proposal-id:string)
    (with-read proposals proposal-id {
      "base-lock":= base,
      "open-time":= open,
      "close-time":= close
      }
      (let* (
          (elapsed (/ (diff-time (at "block-time" (chain-data)) open) 86400.0))
          (remaining-days (/ (diff-time close (at "block-time" (chain-data))) 86400.0))
          (votes-cast (length (select votes ["voter"] (where "proposal-id" (= proposal-id)))))
          (crowd-factor (** (+ 1.0 (/ votes-cast 400.0)) 1.6))
          (time-factor (** (+ 0.1 (/ remaining-days 10.0)) 2.2))
        )
        (* base crowd-factor time-factor)
      )))

  (defun calculate-weight:decimal (proposal-id:string locked:decimal vote-time:time)
    (with-read proposals proposal-id {
      "open-time":= open,
      "close-time":= close,
      "base-lock":= base
      }
      (let* (
          (required (required-lock proposal-id))
          (early-bonus (max 1.0 (** (/ (diff-time close vote-time) 86400.0) 0.8)))
          (commitment-bonus (sqrt (/ locked (max required base))))
        )
        (* locked early-bonus commitment-bonus)
      )))

  (defun cast-vote:bool
    (proposal-id:string choice:string amount:decimal jwt:string)
    (with-read proposals proposal-id {
      "close-time":= close,
      "base-lock":= base
      }
      (enforce (> (diff-time close (at "block-time" (chain-data))) 0.0) "Voting closed")
      (let* ((required (required-lock proposal-id))
             (sender (at "sender" (chain-data))))
        (enforce (>= amount required) "Not enough KDA locked for current timing")
        (coin.transfer sender (format "vote-{}" [proposal-id]) amount)

        ;; Extract and verify JWT (very small payload: pubkey + iat + exp 2 min)
        (let ((payload (at 1 (split jwt ".")))
              (sig (at 2 (split jwt "."))))
          (verify-jwt-signature jwt payload sig))

        (let ((weight (calculate-weight proposal-id amount (at "block-time" (chain-data)))))
          (insert votes (format "{}-{}" [proposal-id sender]) {
            "proposal-id": proposal-id,
            "voter": sender,
            "choice": choice,
            "locked": amount,
            "vote-time": (at "block-time" (chain-data)),
            "jwt": jwt
          })
          (update proposals proposal-id {
            (+ "total-yes" (if (= choice "yes") weight 0.0)),
            (+ "total-no" (if (= choice "no") weight 0.0)),
            (+ "total-neutral" (if (= choice "neutral") weight 0.0))
          })))))
  
  (defun end-voting-and-unlock:string (proposal-id:string)
    (with-read proposals proposal-id {
      "close-time":= close,
      "reward-pool":= pool
      }
      (enforce (<= (at "block-time" (chain-data)) close) "Voting still open")
      (let ((all-voters (select votes ["voter","locked"] (where "proposal-id" (= proposal-id)))))
        (map (lambda (row)
          (coin.transfer (format "vote-{}" [proposal-id]) (at "voter" row) (at "locked" row))
        ) all-voters)
        (format "Voting ended and {} KDA unlocked" [(length all-voters)]))))
)