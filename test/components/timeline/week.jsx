import '../../testHelper';

import React from 'react';
import { findDOMNode } from 'react-dom';
import TestUtils from 'react-addons-test-utils';
import Week from '../../../app/assets/javascripts/components/timeline/week.cjsx';

const createWeek = (opts) => {
  return TestUtils.renderIntoDocument(
    <Week
      index={1}
      blocks={[]}
      meetings={opts.meetings || null}
      edit_permissions={opts.edit_permissions || false}
      week={{ is_new: false }}
    />
  );
};

describe('Week', () => {
  describe('render', () => {
    it('renders an li', () => {
      const TestWeek = (
        <Week
          index={1}
          blocks={[]}
          week={{ is_new: false }}
        />
      );
      // Shallow rendering. See
      // https://facebook.github.io/react/docs/test-utils.html#shallow-rendering
      const renderer = TestUtils.createRenderer();
      renderer.render(TestWeek);
      const result = renderer.getRenderOutput();
      expect(result.type).to.eq('li');
    });
  });

  describe('week add/delete', () => {
    describe('week meetings and edit permissions', () => {
      it('displays', () => {
        const TestWeek = createWeek({ edit_permissions: true, meetings: true });
        const container = TestUtils.scryRenderedDOMComponentsWithClass(TestWeek, 'week__week-add-delete')[0];
        const containerNode = findDOMNode(container);
        expect(containerNode.innerHTML).to.contain('Add Block');
        expect(containerNode.innerHTML).to.contain('Delete Week');
      });
    });
    describe('edit permissions, but no week meetings', () => {
      it('does not display', () => {
        const TestWeek = createWeek({ edit_permissions: true, meetings: false });
        const container = TestUtils.scryRenderedDOMComponentsWithClass(TestWeek, 'week__week-add-delete')[0];
        const containerNode = findDOMNode(container);
        expect(containerNode).to.be.null();
      });
    });
    describe('week meetings, but no edit permissions', () => {
      it('does not display', () => {
        const TestWeek = createWeek({ edit_permissions: false, meetings: true });
        const container = TestUtils.scryRenderedDOMComponentsWithClass(TestWeek, 'week__week-add-delete')[0];
        const containerNode = findDOMNode(container);
        expect(containerNode).to.be.null();
      });
    });
  });
});