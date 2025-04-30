;; skill-grid.clar
;; SkillGrid Growth Tracker - A transparent, immutable record of skill acquisition and development
;; This contract manages skill records, assessments, verification, and growth tracking
;; It allows users to create and manage their skill categories, individual skills,
;; track proficiency levels, and receive verification from trusted evaluators.

;; ============================================================
;; Error constants
;; ============================================================
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SKILL-EXISTS (err u101))
(define-constant ERR-CATEGORY-EXISTS (err u102))
(define-constant ERR-CATEGORY-NOT-FOUND (err u103))
(define-constant ERR-SKILL-NOT-FOUND (err u104))
(define-constant ERR-INVALID-PROFICIENCY (err u105))
(define-constant ERR-VERIFIER-EXISTS (err u106))
(define-constant ERR-NOT-VERIFIER (err u107))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u108))
(define-constant ERR-ALREADY-VERIFIED (err u109))

;; ============================================================
;; Data Maps and Variables
;; ============================================================

;; Tracks categories created by users
(define-map skill-categories
  { owner: principal, category-id: uint }
  { name: (string-ascii 100), description: (string-ascii 500), created-at: uint }
)

;; Tracks individual skills within categories
(define-map skills
  { owner: principal, skill-id: uint }
  { 
    name: (string-ascii 100), 
    description: (string-ascii 500), 
    category-id: uint, 
    created-at: uint 
  }
)

;; Tracks current proficiency levels for each skill
(define-map skill-proficiencies
  { owner: principal, skill-id: uint }
  { current-level: uint, target-level: uint, last-updated: uint }
)

;; Records all skill assessments chronologically
(define-map skill-assessments
  { owner: principal, assessment-id: uint }
  { 
    skill-id: uint, 
    proficiency: uint, 
    notes: (string-ascii 500), 
    timestamp: uint, 
    verified: bool 
  }
)

;; Tracks all verification records
(define-map verifications
  { assessment-id: uint, verifier: principal }
  { timestamp: uint, notes: (string-ascii 500) }
)

;; Stores authorized verifiers for a user
(define-map authorized-verifiers
  { user: principal, verifier: principal }
  { authorized-at: uint }
)

;; Counters to generate unique IDs
(define-data-var next-category-id uint u1)
(define-data-var next-skill-id uint u1)
(define-data-var next-assessment-id uint u1)

;; ============================================================
;; Private Functions
;; ============================================================

;; Check if a proficiency value is valid (1-10)
(define-private (is-valid-proficiency (proficiency uint))
  (and (>= proficiency u1) (<= proficiency u10))
)

;; Get the current block height as a timestamp
(define-private (get-current-time)
  block-height
)

;; Generate a new category ID and increment the counter
(define-private (generate-category-id)
  (let ((current-id (var-get next-category-id)))
    (var-set next-category-id (+ current-id u1))
    current-id
  )
)

;; Generate a new skill ID and increment the counter
(define-private (generate-skill-id)
  (let ((current-id (var-get next-skill-id)))
    (var-set next-skill-id (+ current-id u1))
    current-id
  )
)

;; Generate a new assessment ID and increment the counter
(define-private (generate-assessment-id)
  (let ((current-id (var-get next-assessment-id)))
    (var-set next-assessment-id (+ current-id u1))
    current-id
  )
)

;; Check if category exists
(define-private (category-exists (owner principal) (category-id uint))
  (map-has? skill-categories { owner: owner, category-id: category-id })
)

;; Check if skill exists
(define-private (skill-exists (owner principal) (skill-id uint))
  (map-has? skills { owner: owner, skill-id: skill-id })
)

;; Check if assessment exists
(define-private (assessment-exists (owner principal) (assessment-id uint))
  (map-has? skill-assessments { owner: owner, assessment-id: assessment-id })
)

;; Check if user is an authorized verifier
(define-private (is-verifier (user principal) (verifier principal))
  (map-has? authorized-verifiers { user: user, verifier: verifier })
)

;; ============================================================
;; Read-Only Functions
;; ============================================================

;; Get a skill category by ID
(define-read-only (get-category (owner principal) (category-id uint))
  (map-get? skill-categories { owner: owner, category-id: category-id })
)

;; Get a skill by ID
(define-read-only (get-skill (owner principal) (skill-id uint))
  (map-get? skills { owner: owner, skill-id: skill-id })
)

;; Get current proficiency for a skill
(define-read-only (get-skill-proficiency (owner principal) (skill-id uint))
  (map-get? skill-proficiencies { owner: owner, skill-id: skill-id })
)

;; Get a specific assessment by ID
(define-read-only (get-assessment (owner principal) (assessment-id uint))
  (map-get? skill-assessments { owner: owner, assessment-id: assessment-id })
)

;; Check if an assessment has been verified
(define-read-only (is-assessment-verified (owner principal) (assessment-id uint) (verifier principal))
  (map-has? verifications { assessment-id: assessment-id, verifier: verifier })
)

;; Check if a user is authorized as a verifier
(define-read-only (check-verifier-status (user principal) (verifier principal))
  (map-get? authorized-verifiers { user: user, verifier: verifier })
)

;; Calculates the skill gap for a specific skill
(define-read-only (calculate-skill-gap (owner principal) (skill-id uint))
  (match (get-skill-proficiency owner skill-id)
    proficiency-data
      (let (
        (current (get current-level proficiency-data))
        (target (get target-level proficiency-data))
      )
      {
        skill-id: skill-id,
        current-level: current,
        target-level: target,
        gap: (- target current)
      })
    none
      none
  )
)

;; ============================================================
;; Public Functions
;; ============================================================

;; Create a new skill category
(define-public (create-category (name (string-ascii 100)) (description (string-ascii 500)))
  (let (
    (owner tx-sender)
    (category-id (generate-category-id))
    (current-time (get-current-time))
  )
    (if (map-has? skill-categories { owner: owner, category-id: category-id })
      ERR-CATEGORY-EXISTS
      (begin
        (map-set skill-categories
          { owner: owner, category-id: category-id }
          { name: name, description: description, created-at: current-time }
        )
        (ok category-id)
      )
    )
  )
)

;; Create a new skill within a category
(define-public (create-skill 
  (name (string-ascii 100)) 
  (description (string-ascii 500)) 
  (category-id uint)
)
  (let (
    (owner tx-sender)
    (skill-id (generate-skill-id))
    (current-time (get-current-time))
  )
    (if (not (category-exists owner category-id))
      ERR-CATEGORY-NOT-FOUND
      (begin
        (map-set skills
          { owner: owner, skill-id: skill-id }
          { 
            name: name, 
            description: description, 
            category-id: category-id, 
            created-at: current-time 
          }
        )
        ;; Initialize with default proficiency values
        (map-set skill-proficiencies
          { owner: owner, skill-id: skill-id }
          { current-level: u1, target-level: u1, last-updated: current-time }
        )
        (ok skill-id)
      )
    )
  )
)

;; Record a new skill assessment
(define-public (record-assessment 
  (skill-id uint) 
  (proficiency uint) 
  (notes (string-ascii 500))
)
  (let (
    (owner tx-sender)
    (assessment-id (generate-assessment-id))
    (current-time (get-current-time))
  )
    (if (not (skill-exists owner skill-id))
      ERR-SKILL-NOT-FOUND
      (if (not (is-valid-proficiency proficiency))
        ERR-INVALID-PROFICIENCY
        (begin
          ;; Create assessment record
          (map-set skill-assessments
            { owner: owner, assessment-id: assessment-id }
            { 
              skill-id: skill-id, 
              proficiency: proficiency, 
              notes: notes, 
              timestamp: current-time,
              verified: false
            }
          )
          ;; Update current proficiency
          (map-set skill-proficiencies
            { owner: owner, skill-id: skill-id }
            {
              current-level: proficiency,
              target-level: (get target-level (default-to 
                { current-level: u1, target-level: u1, last-updated: u0 } 
                (get-skill-proficiency owner skill-id)
              )),
              last-updated: current-time
            }
          )
          (ok assessment-id)
        )
      )
    )
  )
)

;; Set a target proficiency level for a skill
(define-public (set-target-level (skill-id uint) (target-level uint))
  (let (
    (owner tx-sender)
    (current-time (get-current-time))
  )
    (if (not (skill-exists owner skill-id))
      ERR-SKILL-NOT-FOUND
      (if (not (is-valid-proficiency target-level))
        ERR-INVALID-PROFICIENCY
        (begin
          (map-set skill-proficiencies
            { owner: owner, skill-id: skill-id }
            {
              current-level: (get current-level (default-to 
                { current-level: u1, target-level: u1, last-updated: u0 } 
                (get-skill-proficiency owner skill-id)
              )),
              target-level: target-level,
              last-updated: current-time
            }
          )
          (ok true)
        )
      )
    )
  )
)

;; Authorize a new verifier
(define-public (authorize-verifier (verifier principal))
  (let (
    (user tx-sender)
    (current-time (get-current-time))
  )
    (if (is-verifier user verifier)
      ERR-VERIFIER-EXISTS
      (begin
        (map-set authorized-verifiers
          { user: user, verifier: verifier }
          { authorized-at: current-time }
        )
        (ok true)
      )
    )
  )
)

;; Remove a verifier's authorization
(define-public (remove-verifier (verifier principal))
  (let (
    (user tx-sender)
  )
    (if (not (is-verifier user verifier))
      ERR-NOT-VERIFIER
      (begin
        (map-delete authorized-verifiers { user: user, verifier: verifier })
        (ok true)
      )
    )
  )
)

;; Verify a user's skill assessment
(define-public (verify-assessment (owner principal) (assessment-id uint) (notes (string-ascii 500)))
  (let (
    (verifier tx-sender)
    (current-time (get-current-time))
  )
    (if (not (is-verifier owner verifier))
      ERR-NOT-VERIFIER
      (if (not (assessment-exists owner assessment-id))
        ERR-ASSESSMENT-NOT-FOUND
        (if (is-assessment-verified owner assessment-id verifier)
          ERR-ALREADY-VERIFIED
          (begin
            ;; Record verification
            (map-set verifications
              { assessment-id: assessment-id, verifier: verifier }
              { timestamp: current-time, notes: notes }
            )
            ;; Mark the assessment as verified
            (match (get-assessment owner assessment-id)
              assessment-data
                (map-set skill-assessments
                  { owner: owner, assessment-id: assessment-id }
                  (merge assessment-data { verified: true })
                )
              none
                false
            )
            (ok true)
          )
        )
      )
    )
  )
)

;; Update an existing skill category
(define-public (update-category (category-id uint) (name (string-ascii 100)) (description (string-ascii 500)))
  (let (
    (owner tx-sender)
  )
    (if (not (category-exists owner category-id))
      ERR-CATEGORY-NOT-FOUND
      (match (get-category owner category-id)
        category-data
          (begin
            (map-set skill-categories
              { owner: owner, category-id: category-id }
              (merge category-data { name: name, description: description })
            )
            (ok true)
          )
        none
          ERR-CATEGORY-NOT-FOUND
      )
    )
  )
)

;; Update an existing skill
(define-public (update-skill 
  (skill-id uint) 
  (name (string-ascii 100)) 
  (description (string-ascii 500)) 
  (category-id uint)
)
  (let (
    (owner tx-sender)
  )
    (if (not (skill-exists owner skill-id))
      ERR-SKILL-NOT-FOUND
      (if (not (category-exists owner category-id))
        ERR-CATEGORY-NOT-FOUND
        (match (get-skill owner skill-id)
          skill-data
            (begin
              (map-set skills
                { owner: owner, skill-id: skill-id }
                (merge skill-data { 
                  name: name, 
                  description: description, 
                  category-id: category-id 
                })
              )
              (ok true)
            )
          none
            ERR-SKILL-NOT-FOUND
        )
      )
    )
  )
)