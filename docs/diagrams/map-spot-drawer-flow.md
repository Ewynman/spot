# Map spot preview flow

```mermaid
flowchart TD
  idle[Map idle]
  preview[Compact SpotPreviewCard]
  detail[SpotDetailSheet]
  cluster[Cluster tap]
  carousel[Coincident carousel]

  idle -->|tap pin| preview
  idle -->|tap cluster| cluster
  cluster -->|members spread| idle
  cluster -->|coincident| carousel
  carousel --> preview
  preview -->|Like or Save| preview
  preview -->|tap card / swipe up| detail
  preview -->|empty map| idle
  preview -->|other pin| preview
  detail -->|dismiss| preview
```

See [../product/map-experience.md](../product/map-experience.md).
