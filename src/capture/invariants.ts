export interface ResourceState { state: string; activeTracks: number; timers: number; listeners: number }
export type InvariantCode = 'microphone_resources' | 'camera_resources' | 'finalized_hardware';
/** Pure checks are shared by runtime diagnostics and failure-injection tests. */
export function inspectInvariants(microphone: ResourceState, camera: ResourceState, finalized: boolean): InvariantCode[] {
  const issues: InvariantCode[] = [];
  for (const [name, resource] of [['microphone', microphone], ['camera', camera]] as const) {
    if (['idle', 'completed', 'error'].includes(resource.state) && (resource.activeTracks || resource.timers || resource.listeners)) issues.push(`${name}_resources`);
  }
  if (finalized && (microphone.activeTracks || camera.activeTracks)) issues.push('finalized_hardware');
  return issues;
}
