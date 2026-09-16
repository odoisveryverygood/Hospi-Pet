# Contributing to Pa-Co CareGraph

## Branches

- `main`: final stable submission
- `integration`: combined testing branch
- `backend-jac`: backend and Jac graph work
- `frontend-ui`: frontend and visual work

## File ownership

### Backend owner

- `main.jac`
- `jac.toml`
- `models.sv.jac`
- `extraction.sv.jac`
- `walkers.sv.jac`
- `patient_agent.sv.jac`
- `endpoints.sv.jac`
- `tests/`
- `CONTRACT.md`

### Frontend owner

- `frontend.cl.jac`
- `frontend.impl.jac`
- `components/`
- `styles/`
- frontend mock data
- frontend tests

## Rules

- Never code directly on `main`.
- Never force-push.
- Never commit secrets.
- Pull `integration` before beginning a major task.
- Commit small working milestones.
- Use pull requests into `integration`.
- Only merge `integration` into `main` after the complete demo works.
- Do not edit files owned by the other developer without discussing it.
- Do not resolve merge conflicts by deleting the other developer’s work.
- `CONTRACT.md` is controlled by the backend owner.
- The frontend developer requests contract changes instead of changing it silently.
