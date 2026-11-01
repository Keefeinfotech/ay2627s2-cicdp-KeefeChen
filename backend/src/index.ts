import { getWelcomeMessage } from '../../backend/src/shared/utils/request';

function main(): void {
  const user = 'Developer';
  const message = getWelcomeMessage(user);
  
  console.log(message);
}