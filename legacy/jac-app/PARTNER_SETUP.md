# Partner setup

Before starting, accept the GitHub collaborator invitation for the Pa-Co
CareGraph repository.

## First-time setup

Copy and paste these commands:

```bash
git clone https://github.com/odoisveryverygood/pa-co-caregraph.git
cd pa-co-caregraph
git fetch origin
git checkout -b frontend-ui origin/integration
git push -u origin frontend-ui
```

The `frontend-ui` branch must be created from `integration`, not from `main` or
`backend-jac`.

## Daily workflow

Before beginning frontend work, copy and paste:

```bash
git checkout frontend-ui
git status
git fetch origin
git merge origin/integration
```

Resolve any merge conflicts carefully. Do not delete backend work to resolve a
conflict, and discuss changes to backend-owned files with the backend owner.

## After making frontend changes

Stage only the frontend-owned files, then commit and push:

```bash
git add frontend.cl.jac frontend.impl.jac components styles
git commit -m "describe the frontend milestone"
git push origin frontend-ui
```

Use a short, specific milestone description in place of
`describe the frontend milestone`. Never commit secrets, environment files,
private medical data, or real patient data.

## Open a pull request

On GitHub, open a pull request with:

- base branch: `integration`
- compare branch: `frontend-ui`

Use pull requests for all frontend changes that need to enter `integration`.
Do not merge directly into `main`.
