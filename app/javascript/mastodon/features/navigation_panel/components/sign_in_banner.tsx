import { FormattedMessage } from 'react-intl';

import {
  invitationUrl,
  registrationsOpen,
  sso_redirect,
} from 'mastodon/initial_state';
import { useAppSelector } from 'mastodon/store';

export const SignInBanner: React.FC = () => {
  let signupButton: React.ReactNode;

  const signupUrl = useAppSelector(
    (state) => state.server.server.item?.registrations.url ?? '/auth/sign_up',
  );

  if (sso_redirect) {
    return (
      <div className='sign-in-banner'>
        <p>
          <strong>
            <FormattedMessage
              id='sign_in_banner.mastodon_is'
              defaultMessage='A federated social platform that answers to its members, not an algorithm.'
            />
          </strong>
        </p>
        <p>
          <FormattedMessage
            id='sign_in_banner.follow_anyone'
            defaultMessage='Verify who you are once. Then operate under callsigns you chose, pseudonymously.'
          />
        </p>
        <a
          href={sso_redirect}
          data-method='post'
          className='button button--block button-secondary'
        >
          <FormattedMessage
            id='sign_in_banner.sso_redirect'
            defaultMessage='Log in with populus.social'
          />
        </a>
      </div>
    );
  }

  if (registrationsOpen) {
    signupButton = (
      <a href={signupUrl} className='button button--block'>
        <FormattedMessage
          id='sign_in_banner.create_account'
          defaultMessage='Create account'
        />
      </a>
    );
  } else {
    signupButton = (
      <a href={invitationUrl} className='button button--block'>
        <FormattedMessage
          id='sign_in_banner.request_invitation'
          defaultMessage='Request an invitation'
        />
      </a>
    );
  }

  return (
    <div className='sign-in-banner'>
      <p>
        <strong>
          <FormattedMessage
            id='sign_in_banner.mastodon_is'
            defaultMessage='A federated social platform that answers to its members, not an algorithm.'
          />
        </strong>
      </p>
      <p>
        <FormattedMessage
          id='sign_in_banner.follow_anyone'
          defaultMessage='Verify who you are once. Then operate under callsigns you chose, pseudonymously.'
        />
      </p>
      {signupButton}
      <a href='/auth/sign_in' className='button button--block button-secondary'>
        <FormattedMessage id='sign_in_banner.sign_in' defaultMessage='Login' />
      </a>
    </div>
  );
};
