import { ServiceUnavailableException } from '@nestjs/common';
import type { ObjectStore } from '../application/ports.js';

export class DisabledObjectStore implements ObjectStore {
  private unavailable(): never {
    throw new ServiceUnavailableException('Las fotos no están habilitadas en este entorno.');
  }
  async signUpload(): Promise<never> {
    return this.unavailable();
  }
  async signRead(): Promise<never> {
    return this.unavailable();
  }
  async head(): Promise<never> {
    return this.unavailable();
  }
  async read(): Promise<never> {
    return this.unavailable();
  }
  async write(): Promise<never> {
    return this.unavailable();
  }
  async delete(): Promise<never> {
    return this.unavailable();
  }
  async cleanup(): Promise<never> {
    return this.unavailable();
  }
}
